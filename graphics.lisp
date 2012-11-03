(import * from base64)

(deftuple rgb (r g b))
(deftuple rgba (r g b a))

(defmethod css-color (x) (rgb? x)
  (labels ((hexs (x)
             (declare (ignorable x))
             (slice (+ "00" (uppercase (js-code "(d$$x.toString(16))"))) -2)))
    ~"#{(hexs x.r)}{(hexs x.g)}{(hexs x.b)}"))

(defmethod css-color (x) (rgba? x)
  ~"rgba({x.r},{x.g},{x.b},{x.a})")

(defun parse-color (x)
  (labels ((hexv (x) (logior 0 ~"0x{x}")))
    (let ((rgb ((regexp "^rgb\\((\\d+),(\\d+),(\\d+)\\)$").exec x))
          (rgba ((regexp "^rgba\\((\\d+),(\\d+),(\\d+),(\\d+)\\)$").exec x))
          (hex3 ((regexp "^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$").exec x))
          (hex6 ((regexp "^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$").exec x)))
      (cond
        (rgb (rgb (second rgb) (third rgb) (fourth rgb)))
        (rgba (rgba (second rgba) (third rgba) (fourth rgba) (fifth rgba)))
        (hex3 (rgb (* (hexv (second hex3)) 17)
                   (* (hexv (third hex3)) 17)
                   (* (hexv (fourth hex3)) 17)))
        (hex6 (rgb (hexv (second hex6))
                   (hexv (third hex6))
                   (hexv (fourth hex6))))
        (true (rgb 192 192 192))))))

(defun random-color ()
  (new-rgb (+ 128 (random-int 64))
           (+ 128 (random-int 64))
           (+ 128 (random-int 64))))

(defmacro with-canvas (canvas &rest body)
  (let ((ctx (gensym)))
    `(let ((,ctx (funcall (. ,canvas getContext) "2d")))
       (macrolet ((,#"save" ()
                    `(funcall (. ,',ctx save)))
                  (,#"restore" ()
                    `(funcall (. ,',ctx restore)))
                  (,#"scale" (x y)
                    `(funcall (. ,',ctx scale) ,x ,y))
                  (,#"translate" (x y)
                    `(funcall (. ,',ctx translate) ,x ,y))
                  (,#"rotate" (angle)
                    `(funcall (. ,',ctx rotate) ,angle))
                  (,#"transform" (a b c d e f)
                    `(funcall (. ,',ctx transform) ,a ,b ,c ,d ,e ,f))
                  (,#"set-transform" (a b c d e f)
                    `(funcall (. ,',ctx setTransform) ,a ,b ,c ,d ,e ,f))
                  (,#"reset-transform" ()
                    `(funcall (. ,',ctx resetTransform)))
                  (,#"begin-path" ()
                    `(funcall (. ,',ctx beginPath)))
                  (,#"close-path" ()
                    `(funcall (. ,',ctx closePath)))
                  (,#"move-to" (x y)
                    `(funcall (. ,',ctx moveTo) ,x ,y))
                  (,#"line-to" (x y)
                    `(funcall (. ,',ctx lineTo) ,x ,y))
                  (,#"bez2-to" (x1 y1 x2 y2)
                    `(funcall (. ,',ctx quadraticCurveTo) ,x1 ,y1 ,x2 ,y2))
                  (,#"bez3-to" (x1 y1 x2 y2 x3 y3)
                    `(funcall (. ,',ctx bezierCurveTo) ,x1 ,y1 ,x2 ,y2 ,x3 ,y3))
                  (,#"fill-style" (x)
                    `(setf (. ,',ctx fillStyle) ,x))
                  (,#"stroke-style" (x)
                    `(setf (. ,',ctx strokeStyle) ,x))
                  (,#"line-width" (x)
                    `(setf (. ,',ctx lineWidth) ,x))
                  (,#"fill" ()
                    `(funcall (. ,',ctx fill)))
                  (,#"fill-rect" (x0 y0 w h)
                    `(funcall (. ,',ctx fillRect) ,x0 ,y0 ,w ,h))
                  (,#"stroke" ()
                    `(funcall (. ,',ctx stroke)))
                  (,#"clip" ()
                    `(funcall (. ,',ctx clip)))
                  (,#"reset-clip" ()
                    `(funcall (. ,',ctx resetClip)))
                  (,#"shadow" (color dx dy blur)
                    `(progn
                       (setf (. ,',ctx shadowColor) ,color)
                       (setf (. ,',ctx shadowOffsetX) ,dx)
                       (setf (. ,',ctx shadowOffsetY) ,dy)
                       (setf (. ,',ctx shadowBlur) ,blur)))
                  (,#"font" (x)
                    `(setf (. ,',ctx font) ,x))
                  (,#"measure-text" (x)
                    `(funcall (. ,',ctx measureText) ,x))
                  (,#"text-baseline" (x)
                    `(setf (. ,',ctx textBaseline) ,x))
                  (,#"text-width" (x)
                    `(. (funcall (. ,',ctx measureText) ,x) width))
                  (,#"fill-text" (text x y &optional max-width)
                    `(funcall (. ,',ctx fillText) ,text ,x ,y (or ,max-width 1000000)))
                  (,#"stroke-text" (text x y &optional max-width)
                    `(funcall (. ,',ctx strokeText) ,text ,x ,y (or ,max-width 1000000)))
                  (,#"arc" (x y r start-angle end-angle ccw)
                    `(funcall (. ,',ctx arc) ,x ,y ,r ,start-angle ,end-angle ,ccw))
                  (,#"line" (x0 y0 x1 y1)
                    `(progn
                       (,#"begin-path")
                       (,#"move-to" ,x0 ,y0)
                       (,#"line-to" ,x1 ,y1)
                       (,#"stroke")))
                  (,#"circle" (x y r)
                    `(progn
                       (,#"begin-path")
                       (,#"arc" ,x ,y ,r 0 (* 2 pi) false)))
                  (,#"rect" (x0 y0 w h)
                    (let ((xa '#.(gensym))
                          (ya '#.(gensym))
                          (xb '#.(gensym))
                          (yb '#.(gensym)))
                      `(let* ((,xa ,x0)
                              (,ya ,y0)
                              (,xb (+ ,xa ,w))
                              (,yb (+ ,ya ,h)))
                         (,#"begin-path")
                         (,#"move-to" ,xa ,ya)
                         (,#"line-to" ,xb ,ya)
                         (,#"line-to" ,xb ,yb)
                         (,#"line-to" ,xa ,yb)
                         (,#"close-path"))))
                  (,#"image-smoothing" (x)
                    `(setf (. ,',ctx imageSmoothingEnabled) ,x))
                  (,#"image" (src x y &optional w h sx sy sw sh)
                    (cond
                      ((undefined? w)
                       `(funcall (. ,',ctx drawImage) ,src ,x ,y))
                      ((undefined? sx)
                       `(funcall (. ,',ctx drawImage) ,src ,x ,y ,w ,h))
                      (true
                       `(funcall (. ,',ctx drawImage) ,src ,sx ,sy ,sw ,sh ,x ,y ,w ,h)))))
         ,@body))))

(defun image-data-url (filename)
  (+ "data:image/png;base64,"
     (base64-encode (if node-js
                        (get-file filename undefined)
                        (http-get filename null null true)))))

(defun aa-rescale (canvas w h &optional result (aa 4))
  (unless result
    (setf result (create-element "canvas")))
  (let* ((ctx (canvas.getContext "2d"))
         (sw canvas.width)
         (sh canvas.height)
         (data (ctx.getImageData 0 0 sw sh))
         (pixels data.data))
    (setf result.width w)
    (setf result.height h)
    (let* ((rctx (result.getContext "2d"))
           (rdata (rctx.getImageData 0 0 w h))
           (rpixels rdata.data)
           (srx (repeat-collect w (list)))
           (sry (repeat-collect h (list)))
           (kx (/ sw w))
           (ky (/ sh h))
           (aaj (map (lambda (i) (/ (+ i 0.5) aa)) (range aa)))
           (kaa (/ (* aa aa))))
      (dotimes (x w)
        (dolist (j aaj)
          (push (* 4 (floor (+ j (* x kx)))) (aref srx x))))
      (dotimes (y h)
        (dolist (j aaj)
          (push (* sw 4 (floor (+ j (* y ky)))) (aref sry y))))
      (dotimes (y h)
        (let ((wp (* w 4)))
          (dotimes (x w)
            (let ((tr 0)
                  (tg 0)
                  (tb 0)
                  (ta 0))
              (dolist (sx (aref srx x))
                (dolist (sy (aref sry y))
                  (let ((a (+ sx sy)))
                    (incf tr (aref pixels a))
                    (incf tg (aref pixels (+ a 1)))
                    (incf tb (aref pixels (+ a 2)))
                    (incf ta (aref pixels (+ a 3))))))
              (setf (aref rpixels wp) (* kaa tr))
              (setf (aref rpixels (+ wp 1)) (* kaa tg))
              (setf (aref rpixels (+ wp 2)) (* kaa tb))
              (setf (aref rpixels (+ wp 3)) (* kaa ta))
              (incf wp 4)))))
      (rctx.putImageData rdata 0 0))
    result))

(export rgb rgba css-color parse-color random-color
        with-canvas
        image-data-url aa-rescale)
