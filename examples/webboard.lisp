(import * from gui)
(import * from layout)
(import * from graphics)

(defvar *image-data* (let ((res #()))
                       (dolist (x '("wp" "wr" "wn" "wb" "wq" "wk"
                                    "bp" "br" "bn" "bb" "bq" "bk"))
                         (setf (aref res x)
                               (image-data-url ~"examples/img/{x}.png")))
                       res))

(defun chessboard ()
  (let** ((w (window 0 0 620 520 title: "Chessboard"))
          (canvas (add-widget w (create-element "canvas")))
          (pselect (add-widget w (create-element "canvas")))
          (clear (add-widget w (button "Clear" #'clear)))
          (start (add-widget w (button "Start" #'start)))
          (flip (add-widget w (button "Flip" #'flip)))
          (m-light (add-widget w (button "Light sq" #'m-light)))
          (m-dark (add-widget w (button "Dark sq" #'m-dark)))
          (m-border (add-widget w (button "Border" #'m-border)))
          (m-background (add-widget w (button "Background" #'m-background)))
          (pos (make-array (list 8 8)))
          (load-count 0)
          (pieces (let ((pieces #()))
                    (dolist (x '("wp" "wr" "wn" "wb" "wq" "wk"
                                 "bp" "br" "bn" "bb" "bq" "bk"))
                      (setf (aref pieces x)
                            (let ((img (create-element "img")))
                              (setf img.onload
                                    (lambda ()
                                      (when (= (incf load-count) 12)
                                        (redraw)
                                        (redraw-pselect))))
                              (setf img.src (aref *image-data* x))
                              img)))
                    pieces))
          (lightsq "#BBCCDD")
          (darksq "#99AABB")
          (border "#778899")
          (background "#EEEEEE")
          (#'start ()
            (parse-fen "rnbqkbnr/
                        pppppppp/
                        8/8/8/8/
                        PPPPPPPP/
                        RNBQKBNR"))
          (#'clear ()
            (parse-fen "8/8/8/8/8/8/8/8"))
          (#'flip ()
            (dotimes (i 32)
              (let ((j (- 63 i)))
                (swap (aref pos (ash i -3) (logand i 7))
                      (aref pos (ash j -3) (logand j 7)))))
            (redraw))
          (#'drag (x y pz)
            (let* ((img (create-element "canvas"))
                   (sq (min (floor (/ canvas.offsetWidth 9))
                            (floor (/ canvas.offsetHeight 9))))
                   (x0 (floor (/ (- canvas.offsetWidth (* sq 8)) 2)))
                   (y0 (floor (/ (- canvas.offsetHeight (* sq 8)) 2)))
                   (m (floor (/ sq 12))))
              (setf img.width sq)
              (setf img.height sq)
              (let ((ctx (img.getContext "2d")))
                (ctx.drawImage pz (- m) (- m) (+ sq m m) (+ sq m m)))
              (set-style img
                         position "absolute"
                         px/left (- x (/ sq 2))
                         px/top (- y (/ sq 2))
                         px/width sq
                         px/height sq)
              (append-child document.body img)
              (tracking (lambda (x y)
                          (set-style img
                                     px/left (- x (/ sq 2))
                                     px/top (- y (/ sq 2))))
                        (lambda (x y)
                          (let* (((cx cy) (element-pos canvas))
                                 (ix (floor (/ (- x cx x0) sq)))
                                 (iy (floor (/ (- y cy y0) sq))))
                            (when (and (<= 0 ix 7) (<= 0 iy 7))
                              (setf (aref pos iy ix) pz)
                              (redraw))
                            (remove-child document.body img)))
                        "move")))
          (#'mousedown (event)
            (event.stopPropagation)
            (event.preventDefault)
            (let (((psx psy) (element-pos pselect))
                  ((cx cy) (element-pos canvas))
                  ((x y) (event-pos event)))
              (cond
                ((and (<= psx x (+ psx pselect.offsetWidth))
                      (<= psy y (+ psy pselect.offsetHeight)))
                 (let ((iy (floor (* (- y psy) 6 (/ pselect.offsetHeight))))
                       (ix (floor (* (- x psx) 2 (/ pselect.offsetWidth)))))
                   (drag x y (aref pieces (+ (aref "wb" (max (min ix 1) 0))
                                             (aref "prnbqk" (max (min iy 5) 0)))))))
                ((and (<= cx x (+ cx canvas.offsetWidth))
                      (<= cy y (+ cy canvas.offsetHeight)))
                 (let* ((sq (min (floor (/ canvas.offsetWidth 9))
                                 (floor (/ canvas.offsetHeight 9))))
                        (x0 (floor (/ (- canvas.offsetWidth (* sq 8)) 2)))
                        (y0 (floor (/ (- canvas.offsetHeight (* sq 8)) 2)))
                        (iy (floor (/ (- y cy y0) sq)))
                        (ix (floor (/ (- x cx x0) sq))))
                   (when (and (<= 0 ix 7) (<= 0 iy 7) (aref pos iy ix))
                     (let ((p (aref pos iy ix)))
                       (setf (aref pos iy ix) undefined)
                       (redraw)
                       (drag x y p))))))))
          (#'redraw-pselect ()
            (setf pselect.width pselect.offsetWidth)
            (setf pselect.height pselect.offsetHeight)
            (let* ((sq (min (floor (/ pselect.offsetWidth 2))
                            (floor (/ pselect.offsetHeight 6))))
                   (x0 (floor (/ (- pselect.offsetWidth (* sq 2)) 2)))
                   (y0 (floor (/ (- pselect.offsetHeight (* sq 6)) 2)))
                   (m (floor (/ sq 12)))
                   (ctx (pselect.getContext "2d")))
              (setf ctx.imageSmoothingEnabled true)
              (dotimes (y 6)
                (dotimes (x 2)
                  (setf ctx.fillStyle "#DDDDDD")
                  (ctx.fillRect (+ x0 (* x sq) 2) (+ y0 (* y sq) 2)
                                (- sq 4) (- sq 4))
                  (let ((img (aref pieces (+ (aref "wb" x) (aref "prnbqk" y)))))
                    (ctx.drawImage img
                                   (- (+ x0 (* sq x)) m)
                                   (- (+ y0 (* sq y)) m)
                                   (+ sq m m)
                                   (+ sq m m)))))))
          (#'redraw ()
            (setf canvas.width canvas.offsetWidth)
            (setf canvas.height canvas.offsetHeight)
            (let* ((sq (min (floor (/ canvas.offsetWidth 9))
                            (floor (/ canvas.offsetHeight 9))))
                   (x0 (floor (/ (- canvas.offsetWidth (* sq 8)) 2)))
                   (y0 (floor (/ (- canvas.offsetHeight (* sq 8)) 2)))
                   (m (floor (/ sq 12)))
                   (ctx (canvas.getContext "2d")))
              (setf ctx.fillStyle background)
              (ctx.fillRect 0 0 canvas.width canvas.height)
              (setf ctx.fillStyle border)
              (ctx.fillRect (- x0 m) (- y0 m)
                            (+ (* 8 sq) m m) (+ (* 8 sq) m m))
              (dotimes (y 8)
                (dotimes (x 8)
                  (setf ctx.fillStyle (if (odd? (+ x y)) darksq lightsq))
                  (ctx.fillRect (+ x0 (* sq x)) (+ y0 (* sq y)) sq sq)
                  (when (aref pos y x)
                    (ctx.drawImage (aref pos y x)
                                   (- (+ x0 (* sq x)) m)
                                   (- (+ y0 (* sq y)) m)
                                   (+ sq m m)
                                   (+ sq m m)))))))
          (#'m-light ()
            (ask-color m-light.offsetLeft m-light.offsetTop "Light squares color"
                       lightsq (lambda (c) (when c (setf lightsq c) (redraw)))))
          (#'m-dark ()
            (ask-color m-light.offsetLeft m-light.offsetTop "Dark squares color"
                       darksq (lambda (c) (when c (setf darksq c) (redraw)))))
          (#'m-border ()
            (ask-color m-light.offsetLeft m-light.offsetTop "Border color"
                       border (lambda (c) (when c (setf border c) (redraw)))))
          (#'m-background ()
            (ask-color m-light.offsetLeft m-light.offsetTop "Background color"
                       background (lambda (c) (when c (setf background c) (redraw)))))
          (#'parse-fen (fen)
            (setf pos (make-array (list 8 8)))
            (let ((y 0)
                  (x 0))
              (dolist (c fen)
                (cond
                  ((find c "prnbqk")
                   (setf (aref pos y x) (aref pieces (+ "b" c)))
                   (incf x))
                  ((find c "PRNBQK")
                   (setf (aref pos y x) (aref pieces (+ "w" (lowercase c))))
                   (incf x))
                  ((find c "12345678")
                   (incf x (atoi c)))
                  ((= c "/")
                   (setf x 0)
                   (incf y)))))
            (redraw)))
    (setf w.client.onmousedown #'mousedown)
    (setf canvas.data-resize #'redraw)
    (setf pselect.data-resize #'redraw-pselect)
    (set-layout w (H border: 8 spacing: 8
                     size: 100
                     (V (V spacing: 2
                           (dom clear)
                           (dom start)
                           (dom flip)
                           (dom m-light)
                           (dom m-dark)
                           (dom m-border)
                           (dom m-background))
                        size: 300
                        (dom pselect))
                     size: undefined
                     (dom canvas)))
    (start)
    (show-window w center: true)))

(defun main ()
  (chessboard))

(main)