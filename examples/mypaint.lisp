(import * from gui)
(import * from graphics)

(defun color-button (parent color callback)
  (let ((div (create-element "div")))
    (set-style div
               position "absolute"
               border ~"solid 1px #000000"
               backgroundColor ~"rgb({(first color)},{(second color)},{(third color)})")
    (append-child parent div)

    (set-handler div oncontextmenu
                 (funcall (. event preventDefault))
                 (funcall (. event stopPropagation)))

    (set-handler div onmousedown
                 (funcall (. event preventDefault))
                 (funcall (. event stopPropagation))
                 (funcall callback color (. event button) div))
    div))

(defun luma (color)
  (+ (first color) (* 2 (second color)) (* 0.9 (third color))))

(defun palette (parent rows w h callback)
  (let ((colors (list))
        (layout (:H :spacing 4))
        (crow null))
    (dotimes (r 2)
      (dotimes (g 2)
        (dotimes (b 2)
          (push (list (* r 255) (* g 255) (* b 255) 255) colors)
          (push (list (+ 64 (* r 128)) (+ 64 (* g 128)) (+ 64 (* b 128)) 255) colors))))
    (dolist (c (sort colors (lambda (a b) (> (luma a) (luma b)))))
      (when (null? crow)
        (setf crow (:V :size w :spacing 4 (:V)))
        (push crow (layout-node-children layout)))
      (push (:Vdiv (color-button parent c callback) :size w)
            (layout-node-children crow))
      (when (= (length (layout-node-children crow)) (1+ rows))
        (setf crow null)))
    (:H :border 4
        (:V layout)
        (:H))))

(defun hline (data x0 x1 y r g b a)
  "Draws an horizontal line on canvas image [data] from [x0] to [x1] at height [y] with color [r g b a]"
  (let ((width (. data width))
        (height (. data height))
        (pixels (. data data)))
    (do ((p (* (+ (* y width) x0) 4) (+ p 4))
         (count (- x1 x0) (1- count)))
        ((= count 0))
      (setf (aref pixels p)       r)
      (setf (aref pixels (+ p 1)) g)
      (setf (aref pixels (+ p 2)) b)
      (setf (aref pixels (+ p 3)) a))))

(defun box (data x0 y0 x1 y1 color)
  "Fills a box on canvas image [data] from [x0 y0] to [x1 y1] with [color]"
  (let ((width (. data width))
        (height (. data height)))
    (when (< x0 0) (setf x0 0))
    (when (> x1 width) (setf x1 width))
    (when (< y0 0) (setf y0 0))
    (when (> y1 height) (setf y1 height))
    (when (< x0 x1)
      (do ((y y0 (1+ y))
           (r (first color))
           (g (second color))
           (b (third color))
           (a (fourth color)))
          ((>= y y1))
        (hline data x0 x1 y r g b a)))))

(defun clear (data color)
  "Clears the whole canvas image [data] with specified [color]"
  (box data 0 0 (. data width) (. data height) color))

(defun frame (data x0 y0 x1 y1 pw ph color)
  "Draws a rectangular frame with specified pen size [pw ph] and [color]"
  (let ((width (. data width))
        (height (. data height)))
    (if (or (>= (+ x0 pw) (- x1 pw))
            (>= (+ y0 ph) (- y1 ph)))
        (box data x0 y0 x1 y1 color)
        (progn
          (box data x0 y0 x1 (+ y0 ph) color)
          (box data x0 (+ y0 ph) (+ x0 pw) (- y1 ph) color)
          (box data (- x1 pw) (+ y0 ph) x1 (- y1 ph) color)
          (box data x0 (- y1 ph) x1 y1 color)))))

(defun line (data x0 y0 x1 y1 pw ph color)
  "Draws a line fro [x0 y0] to [x1 y1] with specified pen size [pw ph] and [color]"
  (let ((width (. data width))
        (height (. data height)))
    (when (> y0 y1)
      (swap y0 y1)
      (swap x0 x1))
    (let ((xa (max 0 (min x0 x1)))
          (xb (min width (+ pw (max x0 x1)))))
      (if (or (= x0 x1) (= y0 y1))
          (box data xa y0 xb (+ y1 ph) color)
          (let* ((k (/ (- x1 x0) (- y1 y0)))
                 (dx (abs (* ph k))))
            (do ((r (first color))
                 (g (second color))
                 (b (third color))
                 (a (fourth color))
                 (y y0 (1+ y))
                 (yend (+ y1 ph))
                 (left (+ (/ k 2) 0.5 (if (< x0 x1) (- x0 dx) x0)) (+ left k))
                 (right (+ (/ k 2) 0.5 (if (< x0 x1) (+ x0 pw) (+ x0 pw dx))) (+ right k)))
                ((>= y yend))
              (let ((x0 (max (floor left) xa))
                    (x1 (min (floor right) xb)))
                (when (< x0 x1)
                  (hline data x0 x1 y r g b a)))))))))

(defstruct paint
  frame
  pic
  data
  old-data
  start-data
  (commands (list))
  (undone (list))
  (zoom 1)
  (bg (list 255 255 255 255))
  (fg (list   0   0   0 255))
  (pen 1)
  (selection null))

(defun copy-pixels (dst src)
  "Copies all pixels from ImageData [src] to ImageData [dst] (they must have the same size)"
  (let ((width (. dst width))
        (height (. dst height))
        (src-data (. src data))
        (dst-data (. dst data)))
    (dotimes (i (* width height 4))
      (setf (aref dst-data i) (aref src-data i)))))

(defvar *tools* (list))

(defmacro deftool (name &rest body)
  `(progn
     (defun ,name (pw) ,@body)
     (push ',name *tools*)))

(defmacro exec (vars &rest body)
  `(let (,@(map (lambda (x) `(,x ,x)) vars))
     (push (lambda () ,@body) (paint-commands pw))
     (funcall (last (paint-commands pw)))))

(deftool Pen
    (let ((pts (list)))
      (lambda (msg p btn)
        (cond
          ((= msg 'down)
           (push null (paint-commands pw))
           (copy-pixels (paint-old-data pw) (paint-data pw))
           (setf pts (list p)))
          ((= msg 'move)
           (let* ((sz (paint-pen pw))
                  (hsz (ash sz -1))
                  (color (if (= btn 2) (paint-bg pw) (paint-fg pw))))
             (copy-pixels (paint-data pw) (paint-old-data pw))
             (pop (paint-commands pw))
             (push p pts)
             (exec (pts sz hsz color)
                   (dotimes (i (1- (length pts)))
                     (let ((p0 (aref pts i))
                           (p (aref pts (1+ i))))
                       (line (paint-data pw)
                             (- (first p0) hsz) (- (second p0) hsz)
                             (- (first p) hsz) (- (second p) hsz)
                             sz sz color))))))))))

(deftool Line
    (let ((p0 null))
      (lambda (msg p btn)
        (cond
          ((= msg 'down)
           (copy-pixels (paint-old-data pw) (paint-data pw))
           (push null (paint-commands pw))
           (setf p0 p))
          ((= msg 'move)
           (let* ((sz (paint-pen pw))
                  (hsz (ash sz -1))
                  (color (if (= btn 2) (paint-bg pw) (paint-fg pw))))
             (copy-pixels (paint-data pw) (paint-old-data pw))
             (pop (paint-commands pw))
             (exec (hsz sz p0 p color)
                   (line (paint-data pw)
                         (- (first p0) hsz) (- (second p0) hsz)
                         (- (first p) hsz) (- (second p) hsz)
                         sz sz
                         color))))))))

(deftool Box
    (let ((p0 null))
      (lambda (msg p btn)
        (cond
          ((= msg 'down)
           (copy-pixels (paint-old-data pw) (paint-data pw))
           (push null (paint-commands pw))
           (setf p0 p))
          ((= msg 'move)
           (copy-pixels (paint-data pw) (paint-old-data pw))
           (pop (paint-commands pw))
           (let ((color (if (= btn 2) (paint-bg pw) (paint-fg pw))))
             (exec (p0 p color)
                   (box (paint-data pw)
                        (min (first p0) (first p))
                        (min (second p0) (second p))
                        (max (first p0) (first p))
                        (max (second p0) (second p))
                        color))))))))

(deftool Frame
  (let ((p0 null))
    (lambda (msg p btn)
      (cond
        ((= msg 'down)
         (copy-pixels (paint-old-data pw) (paint-data pw))
         (push null (paint-commands pw))
         (setf p0 p))
        ((= msg 'move)
         (copy-pixels (paint-data pw) (paint-old-data pw))
         (pop (paint-commands pw))
         (let ((color (if (= btn 2) (paint-bg pw) (paint-fg pw)))
               (sz (paint-pen pw)))
           (exec (p0 p color sz)
                 (frame (paint-data pw)
                        (min (first p0) (first p))
                        (min (second p0) (second p))
                        (max (first p0) (first p))
                        (max (second p0) (second p))
                        sz sz
                        color))))))))

(defun byte-array (n)
  "Creates an byte array of size [n]"
  (js-code "(new Uint8Array(d$$n))"))

(deftool Fill
    (lambda (msg p btn)
      (when (= msg 'down)
        (let* ((dst (. (paint-data pw) data))
               (width (. (paint-data pw) width))
               (height (. (paint-data pw) height))
               (color (if (= btn 2) (paint-bg pw) (paint-fg pw)))
               (r (first color))
               (g (second color))
               (b (third color))
               (a (fourth color))
               (i0 (ash (+ (* (second p) width) (first p)) 2))
               (tr (aref dst i0))
               (tg (aref dst (+ i0 1)))
               (tb (aref dst (+ i0 2)))
               (ta (aref dst (+ i0 3))))
          (exec (p tr tg tb ta r g b a)
                (let ((src (byte-array (* width height))))
                  ;; Compute fillable areas
                  (let ((rp 0))
                    (dotimes (i (* width height))
                      (setf (aref src i)
                            (if (and (= (aref dst (+ rp 0)) tr)
                                     (= (aref dst (+ rp 1)) tg)
                                     (= (aref dst (+ rp 2)) tb)
                                     (= (aref dst (+ rp 3)) ta))
                                1 0))
                      (incf rp 4)))
                  (do ((todo (list p)))
                      ((= 0 (length todo)))
                    (let* ((p (pop todo))
                           (x (first p))
                           (y (second p))
                           (i (+ (* y width) x)))
                      (when (aref src i)
                        ;; Move to left if you can
                        (do () ((or (= x 0) (not (aref src (1- i)))))
                          (decf x)
                          (decf i))
                        ;; Horizontal line fill
                        (do ((look-above true)
                             (look-below true))
                            ((or (= x width) (not (aref src i))))

                          ;; Check for holes above
                          (when (> y 0)
                            (if look-above
                                (when (aref src (- i width))
                                  (push (list x (1- y)) todo)
                                  (setf look-above false))
                                (unless (aref src (- i width))
                                  (setf look-above true))))

                          ;; Check for holes below
                          (when (< y (1- height))
                            (if look-below
                                (when (aref src (+ i width))
                                  (push (list x (1+ y)) todo)
                                  (setf look-below false))
                                (unless (aref src (+ i width))
                                  (setf look-below true))))

                          ;; Paint the pixel
                          (let ((i4 (* i 4)))
                            (setf (aref dst i4) r)
                            (setf (aref dst (+ i4 1)) g)
                            (setf (aref dst (+ i4 2)) b)
                            (setf (aref dst (+ i4 3)) a))

                          ;; Ensure this will not be painted again
                          (setf (aref src i) 0)

                          ;; Move to next pixel
                          (incf x)
                          (incf i)))))))))))

(deftool Curve
    (let ((pts (make-array 4))
          (n 0))
      (let* ((sz (paint-pen pw))
             (hsz (ash sz -1)))
        (labels ((avg (a b)
                   (list (/ (+ (first a) (first b)) 2)
                         (/ (+ (second a) (second b)) 2)))
                 (bezdraw (color a b c d levels)
                   (if (= levels 0)
                       (line (paint-data pw)
                             (floor (- (first a) hsz)) (floor (- (second a) hsz))
                             (floor (- (first d) hsz)) (floor (- (second d) hsz))
                             sz sz
                             color)
                       (let* ((ab (avg a b))
                              (bc (avg b c))
                              (cd (avg c d))
                              (abc (avg ab bc))
                              (bcd (avg bc cd))
                              (abcd (avg abc bcd)))
                         (bezdraw color a ab abc abcd (1- levels))
                         (bezdraw color abcd bcd cd d (1- levels))))))
          (lambda (msg p btn)
            (cond
              ((= msg 'down)
               (cond
                 ((or (= n 0) (= n 4))
                  (copy-pixels (paint-old-data pw) (paint-data pw))
                  (setf (aref pts 0) p)
                  (setf (aref pts 1) p)
                  (setf (aref pts 2) p)
                  (setf (aref pts 3) p)
                  (setf n 2)
                  (push null (paint-commands pw)))
                 ((= n 2)
                  (setf (aref pts 1) p)
                  (setf (aref pts 2) p)
                  (setf n 3))
                 (true
                  (setf (aref pts 2) p)
                  (setf n 4))))
              ((= msg 'move)
               (cond
                 ((= n 2)
                  (setf (aref pts 2) p)
                  (setf (aref pts 3) p))
                 ((= n 3)
                  (setf (aref pts 1) p)
                  (setf (aref pts 2) p))
                 ((= n 4)
                  (setf (aref pts 2) p)))
               (copy-pixels (paint-data pw) (paint-old-data pw))
               (pop (paint-commands pw))
               (let ((color (if (= btn 2) (paint-bg pw) (paint-fg pw)))
                     (p0 (aref pts 0))
                     (p1 (aref pts 1))
                     (p2 (aref pts 2))
                     (p3 (aref pts 3)))
                 (exec (color p0 p1 p2 p3)
                       (bezdraw color p0 p1 p2 p3 5))))))))))

(deftool Ellipse
    (let ((p0 null))
      (lambda (msg p btn)
        (cond
          ((= msg 'down)
           (setf p0 p)
           (copy-pixels (paint-old-data pw) (paint-data pw))
           (push null (paint-commands pw)))
          ((= msg 'move)
           (let ((color (if (= btn 2) (paint-bg pw) (paint-fg pw))))
             (copy-pixels (paint-data pw) (paint-old-data pw))
             (pop (paint-commands pw))
             (exec (p0 p color)
                   (let ((x0 (min (first p0) (first p)))
                         (x1 (max (first p0) (first p)))
                         (y0 (min (second p0) (second p)))
                         (y1 (max (second p0) (second p)))
                         (width (. (paint-data pw) width))
                         (height (. (paint-data pw) height))
                         (r (first color))
                         (g (second color))
                         (b (third color))
                         (a (fourth color)))
                     (when (< y0 y1)
                       (let ((cx (/ (+ x0 x1) 2))
                             (cy (/ (+ y0 y1) 2))
                             (ya (max 0 y0))
                             (yb (min height y1))
                             (r2 (* (- y1 y0) (- y1 y0) 0.25))
                             (ratio (/ (- x1 x0) (- y1 y0))))
                         (do ((y ya (1+ y)))
                             ((= y yb))
                           (let* ((dy (- (+ y 0.5) cy))
                                  (dx (* ratio (sqrt (- r2 (* dy dy)))))
                                  (xa (max 0 (floor (- cx dx -0.5))))
                                  (xb (min width (floor (+ cx dx 0.5)))))
                             (when (< xa xb)
                               (hline (paint-data pw) xa xb y r g b a))))))))))))))

(deftool Undo-redo
    (lambda (msg p btn)
      (when (= msg 'down)
        (if (/= btn 2)
            (when (length (paint-commands pw))
              (push (pop (paint-commands pw)) (paint-undone pw))
              (copy-pixels (paint-data pw) (paint-start-data pw))
              (dolist (f (paint-commands pw)) (funcall f)))
            (when (length (paint-undone pw))
              (push (pop (paint-undone pw)) (paint-commands pw))
              (funcall (last (paint-commands pw))))))))

(defmacro deftoolbar ()
  `(defun toolbar (parent cols w h callback)
     "Builds a toolbar with all self-registered tool functions"
     (let (,@(map (lambda (x)
                    `(,x (button ,(symbol-name x)
                                 (lambda () (funcall callback #',x)))))
               *tools*))
       ,@(map (lambda (x)
                `(append-child parent ,x))
              *tools*)
       (:H (:V :spacing 4 :size w
               ,@(map (lambda (x)
                        `(:Hdiv ,x :size h))
                      *tools*))))))

(deftoolbar)

(defun paint (x y w h title)
  (let* ((frame (window x y w h :title title))
         (pic (create-element "canvas"))
         (ctool null)
         (pw (make-paint :frame w
                         :pic pic))
         (palette (palette (window-client frame) 2 30 30
                           (lambda (color button div)
                             (if (= button 2)
                                 (setf (paint-bg pw) color)
                                 (setf (paint-fg pw) color)))))
         (toolbar (toolbar (window-client frame) 1 80 30
                           (lambda (f)
                             (setf ctool (funcall f pw))))))
    (setf (. pic width) 520)
    (setf (. pic height) 340)
    (set-style pic
               position "absolute"
               cursor "crosshair")
    (set-style (window-client frame)
               backgroundColor "#CCCCCC")
    (set-style (window-frame frame)
               backgroundColor "#CCCCCC")
    (append-child (window-client frame) pic)

    (let* ((width (. pic width))
           (height (. pic height))
           (ctx (funcall (. pic getContext) "2d"))
           (data (funcall (. ctx getImageData) 0 0 width height)))

      (setf (window-resize-cback frame)
            (lambda (x0 y0 x1 y1)
              (set-coords palette 8 8 (- x1 x0 8) (- y1 y0 8))
              (set-coords toolbar 8 8 (- x1 x0 8) (- y1 y0 8))
              (set-style pic
                         px/left 96
                         px/top 8
                         px/width (* (paint-zoom pw) (. pic width))
                         px/height (* (paint-zoom pw) (. pic height)))))

      (labels ((update ()
                 (funcall (. ctx putImageData) data 0 0)))

        (set-handler pic oncontextmenu
                     (funcall (. event preventDefault))
                     (funcall (. event stopPropagation)))

        (set-handler pic onmousedown
                     (funcall (. event preventDefault))
                     (funcall (. event stopPropagation))
                     (let* ((p (event-pos event))
                            (p0 (element-pos pic))
                            (x (- (first p) (first p0)))
                            (y (- (second p) (second p0)))
                            (z (paint-zoom pw)))
                       (when ctool
                         (funcall ctool 'down (list (floor (/ x z)) (floor (/ y z))) (. event button))
                         (funcall ctool 'move (list (floor (/ x z)) (floor (/ y z))) (. event button))
                         (update)
                         (tracking (lambda (xx yy)
                                     (let ((x (- xx (first p0)))
                                           (y (- yy (second p0))))
                                       (funcall ctool 'move (list (floor (/ x z)) (floor (/ y z))) (. event button))
                                       (update)))
                                   (lambda (xx yy)
                                     (let ((x (- xx (first p0)))
                                           (y (- yy (second p0))))
                                       (funcall ctool 'up (list (floor (/ x z)) (floor (/ y z))) (. event button))
                                       (update)))
                                   "crosshair"))))

        (setf (paint-data pw) data)

        (clear data (list 255 255 255 255))
        (update)
        (setf (paint-old-data pw) (funcall (. ctx getImageData) 0 0 width height))
        (setf (paint-start-data pw) (funcall (. ctx getImageData) 0 0 width height))

        (show-window frame)
        pw))))

(defun main ()
  (paint 100 100 640 480 "MyPaint"))

(main)
