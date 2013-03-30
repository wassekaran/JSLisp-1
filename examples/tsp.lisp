(import * from gui)
(import * from layout)
(defobject xy (x y))

(defun tsp ()
  (let** ((w (window 0 0 530 566 title: "TSP"))
          (canvas (add-widget w (create-element "canvas")))
          (points (let ((res (list)))
                    (repeat 300
                      (let ((best null)
                            (bestd null))
                        (repeat 100
                          (let* ((p (new-xy (+ 10 (random-int 500))
                                            (+ 10 (random-int 500))))
                                 (d (apply #'min (map (lambda (q)
                                                        (dist p q))
                                                      res))))
                            (when (or (null? best)
                                      (< bestd d))
                              (setf best p)
                              (setf bestd d))))
                        (push best res)))
                    res))
          (#'repaint ()
            (let ((w canvas.offsetWidth)
                  (h canvas.offsetHeight)
                  (ctx (canvas.getContext "2d")))
              (setf canvas.width w)
              (setf canvas.height h)
              (setf ctx.fillStyle "#000")
              (ctx.fillRect 0 0 w h)
              (setf ctx.strokeStyle (if flipped "#F00" "#0F0"))
              (setf ctx.lineWidth 2)
              (ctx.beginPath)
              (let ((p (last points)))
                (ctx.moveTo p.x p.y))
              (dolist (p points)
                (ctx.lineTo p.x p.y))
              (ctx.stroke)
              (setf ctx.fillStyle "#FFF")
              (dolist (p points)
                (ctx.beginPath)
                (ctx.arc p.x p.y 2 0 (* 2 pi) true)
                (ctx.fill))))
          (#'dist (a b)
            (let* ((dx (- a.x b.x))
                   (dy (- a.y b.y)))
              (sqrt (+ (* dx dx) (* dy dy)))))
          (flipped false)
          (#'think ()
            (setf flipped false)
            (repeat 100000
              (let* ((ia (random-int (length points)))
                     (ib (random-int (length points)))
                     (before-ia (if (= ia 0) (1- (length points)) (1- ia)))
                     (after-ib (if (= ib (1- (length points))) 0 (1+ ib))))
                (when (and (/= ia ib after-ib before-ia)
                           (< (+ (dist (aref points before-ia) (aref points ib))
                                 (dist (aref points after-ib) (aref points ia)))
                              (+ (dist (aref points before-ia) (aref points ia))
                                 (dist (aref points after-ib) (aref points ib)))))
                  (setf flipped true)
                  (repeat (ash (if (< ib ia) (+ 1 (length points) (- ib ia)) (- ib ia -1)) -1)
                    (swap (aref points ia) (aref points ib))
                    (when (>= (incf ia) (length points))
                      (setf ia 0))
                    (when (< (decf ib) 0)
                      (setf ib (1- (length points))))))))
            (when flipped
              (set-timeout #'think 0))
            (repaint)))
    (set-layout w (V border: 8 spacing: 8
                     (dom canvas)))
    (setf canvas.data-resize #'repaint)
    (set-handler canvas onmousedown
      (set-timeout #'think 0))
    (show-window w center: true)))

(defun main ()
  (tsp))

(main)