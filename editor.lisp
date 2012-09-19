(import * from gui)
(import * from layout)

(setf *font* "\"Droid Sans Mono\",\"Courier New\",\"Courier\",monospace")
(setf *fontsz* 14)
(setf *line* 16)

(defun font (ctx opts)
  (let ((font ""))
    (when opts.bold
      (incf font " bold"))
    (when opts.italic
      (incf font " italic"))
    (setf ctx.fillStyle (or opts.color "#000000"))
    (setf ctx.font ~"{(slice font 1)} {*fontsz*}px {*font*}")))

(defun signature (d)
  (+ "{"
     (join (map (lambda (k)
                  ~"{k}:{(json (aref d k))}")
                (sort (keys d)))
           ",")
     "}"))

(defobject line
    (text
     start-signature
     end-signature
     sel-x0 sel-x1
     (start-context #())
     (end-context #())
     (sections (list))))

(defobject section (from to style))

(defun compute-end-context (line)
  (do ((ec (copy line.start-context))
       (text line.text)
       (i 0)
       (sections (list)))
      ((>= i (length text))
       (unless (= (last text) "\\")
         (setf ec.preproc false))
       (setf line.sections sections)
       ec)
    (cond
      (ec.mlcomment
       (let ((i0 i))
         (do () ((or (= i (length text))
                     (= (slice text i (+ i 2)) "*/")))
           (incf i))
         (when (= (slice text i (+ i 2)) "*/")
           (setf ec.mlcomment false)
           (incf i 2))
         (push (new-section i0 i #((color "#888888"))) sections)))
      (ec.preproc
       (push (new-section i (length text) #((color "#880088"))) sections)
       (setf i (length text)))
      ((= (slice text i (+ i 2)) "/*")
       (setf ec.mlcomment true))
      ((= (aref text i) "#")
       (setf ec.preproc true))
      ((or (and (= (aref text i) ".") (<= "0" (aref text (1+ i)) "9"))
           (<= "0" (aref text i) "9"))
       (let ((i0 i))
         (if (find (slice text i (+ i 2)) '("0x" "0X"))
             (progn
               (incf i 2)
               (do () ((or (= i (length text))
                           (not (find (aref text i) "0123456789abcdefABCDEF")))
                       (push (new-section i0 i #((color "#884400"))) sections))
                 (incf i)))
             (progn
               (do () ((or (= i (length text))
                           (< (aref text i) "0")
                           (> (aref text i) "9")))
                 (incf i))
               (when (= (aref text i) ".")
                 (incf i)
                 (do () ((or (= i (length text))
                             (< (aref text i) "0")
                             (> (aref text i) "9")))
                   (incf i)))
               (when (find (aref text i) "eE")
                 (incf i)
                 (when (find (aref text i) "+-")
                   (incf i))
                 (do () ((or (= i (length text))
                             (< (aref text i) "0")
                             (> (aref text i) "9")))
                   (incf i)))
               (push (new-section i0 i #((color "#FF4444"))) sections)))))
      ((= (aref text i) "\"")
       (let ((i0 i))
         (incf i)
         (do () ((or (>= i (length text))
                     (= (aref text i) "\""))
                 (when (< i (length text))
                   (incf i))
                 (push (new-section i0 i #((color "#008800"))) sections))
           (if (= (aref text i) "\\")
               (incf i 2)
               (incf i)))))
      ((= (slice text i (+ i 2)) "//")
       (push (new-section i (length text) #((color "#888888"))) sections)
       (setf i (length text)))
      (((regexp "[_a-zA-Z]").exec (aref text i))
       (let ((i0 i))
         (do ()
             ((or (= i (length text))
                  (not ((regexp "[_a-zA-Z0-9]").exec (aref text i))))
              (when (find (slice text i0 i)
                          '("if" "while" "for" "return" "break" "case"
                            "struct" "union" "typedef"
                            "int" "double" "char" "const" "float" "unsigned"))
                (push (new-section i0 i #((bold true)
                                          (color "#0000CC")))
                      sections)))
           (incf i))))
      (true
       (incf i)))))

(defun fix-for-selection (sections x0 x1)
  (let ((new-sections (list)))
    (dolist (s sections)
      (let ((xa (max x0 s.from))
            (xb (min x1 s.to)))
        (if (< xa xb)
            (progn
              (when (> xa s.from)
                (push (new-section s.from xa s.style) new-sections))
              (when (< xb s.to)
                (push (new-section xb s.to s.style) new-sections))
              (push (new-section xa xb
                                 (let ((ss (copy s.style)))
                                   (setf ss.background-color "#FFFF00")
                                   ss))
                    new-sections))
            (push s new-sections))))
    (let ((ss #((background-color "#FFFF00"))))
      (if (= (length sections) 0)
          (push (new-section x0 x1 ss)
                new-sections)
          (progn
            (when (< x0 (first sections).from)
              (push (new-section x0 (min x1 (first sections).from) ss)
                    new-sections))
            (when (> x1 (last sections).to)
              (push (new-section (max x0 (last sections).to) x1 ss)
                    new-sections))
            (dotimes (i (1- (length sections)))
              (let ((s0 (aref sections i))
                    (s1 (aref sections (1+ i))))
                (when (< s0.to s1.from)
                  (let ((xa (max s0.to x0))
                        (xb (min s1.from x1)))
                    (when (< xa xb)
                      (push (new-section xa xb ss) new-sections)))))))))
    (sort new-sections
          (lambda (a b) (< a.from b.from)))))

(defun draw-line (text sections h w
                  ctx x y tx endsel)
  (let ((xx 0))
    (dolist (s sections)
      (when (> s.from xx)
        (let ((part (slice text xx s.from)))
          (font ctx #())
          (ctx.fillText part (+ tx x) y)
          (incf x (ctx.measureText part).width)
          (setf xx s.from)))
      (when (< (+ tx x) w)
        (let ((part (slice text s.from s.to)))
          (font ctx s.style)
          (let ((pw (ctx.measureText part).width))
            (when s.style.background-color
              (setf ctx.fillStyle s.style.background-color)
              (ctx.fillRect (+ tx x) y pw h))
            (setf ctx.fillStyle (or s.style.color "#000000"))
            (ctx.fillText part (+ tx x) y)
            (incf x pw)
            (setf xx s.to)))))
    (when (< (+ tx x) w)
      (when (> (length text) xx)
        (let ((part (slice text xx)))
          (font ctx #())
          (ctx.fillText part (+ tx x) y)
          (incf x (ctx.measureText part).width)))
      (when endsel
        (setf ctx.fillStyle "#FFFF00")
        (ctx.fillRect (+ tx x) y (- w x tx) h)))))

(defun editor (content)
  (let** ((screen (create-element "canvas"))
          (lines (list))
          (cw null)
          (ch *line*)
          (last-width null)
          (last-height null)
          (top 0)
          (left 0)
          (row 0)
          (col 0)
          (s-row 0)
          (s-col 0)
          (#'touch (line)
                   (setf line.start-signature null))
          (#'update ()
                    (setf screen.width screen.offsetWidth)
                    (setf screen.height screen.offsetHeight)
                    (let ((cr top)
                          (ctx (screen.getContext "2d")))
                      (when (null? cw)
                        (font ctx #())
                        (setf cw (/ (ctx.measureText "XXXXXXXXXX").width 10)))
                      (setf ctx.fillStyle "#FFFFFF")
                      (ctx.fillRect 0 0 screen.width screen.height)
                      (setf ctx.textBaseline "top")
                      (do () ((or (>= cr (length lines))
                                  (>= (* (- cr top) ch) screen.offsetHeight)))
                        (let ((current-signature (if (= cr 0)
                                                     ""
                                                     (aref lines (1- cr)).end-signature))
                              (x0 0)
                              (x1 0)
                              (line (aref lines cr)))
                          (when (and (or (/= col s-col)
                                         (/= row s-row))
                                     (or (<= row cr s-row)
                                         (<= s-row cr row)))
                            (cond
                             ((= row s-row)
                              (setf x0 (min col s-col))
                              (setf x1 (max col s-col)))
                             ((= cr (min row s-row))
                              (setf x0 (if (= cr row) col s-col))
                              (setf x1 (1+ (length line.text))))
                             ((= cr (max row s-row))
                              (setf x0 0)
                              (setf x1 (if (= cr row) col s-col)))
                             (true
                              (setf x0 0)
                              (setf x1 (1+ (length line.text))))))
                          (unless (and (= x0 line.sel-x0)
                                       (= x1 line.sel-x1)
                                       (= current-signature line.start-signature))
                            (setf line.start-context
                                  (if (= cr 0)
                                      #()
                                      (copy (aref lines (1- cr)).end-context)))
                            (let ((ec (compute-end-context line))
                                  (text line.text))
                              (when (< x0 x1)
                                (setf line.sections
                                      (fix-for-selection line.sections x0 x1)))
                              (setf line.end-context (copy ec))
                              (setf line.sel-x0 x0)
                              (setf line.sel-x1 x1)
                              (setf line.start-signature current-signature)
                              (setf line.end-signature (signature line.end-context))))
                          (draw-line line.text line.sections
                                     ch screen.offsetWidth
                                     ctx 0 (* (- cr top) ch) (- (* cw left))
                                     (> x1 (length line.text)))
                          (when (= cr row)
                            (setf ctx.fillStyle "#FF0000")
                            (ctx.fillRect (* cw (- col left)) (* ch (- cr top))
                                          2 *line*))
                          (incf cr)))))
          (#'fix ()
                 (let ((screen-lines (floor (/ screen.offsetHeight ch)))
                       (screen-cols (floor (/ screen.offsetWidth cw))))
                   (setf row (max 0 (min (1- (length lines)) row)))
                   (setf col (max 0 (min (length (aref lines row).text) col)))
                   (setf s-row (max 0 (min (1- (length lines)) s-row)))
                   (setf s-col (max 0 (min (length (aref lines s-row).text) s-col)))
                   (setf left (max 0 (- col screen-cols) (min left col)))
                   (setf top (max 0 (- row -1 screen-lines) (min row top (- (length lines) screen-lines)))))
                 (update))
          (#'delete-selection ()
                              (if (= row s-row)
                                  (progn
                                    (setf (aref lines row).text
                                          (+ (slice (aref lines row).text 0 (min col s-col))
                                             (slice (aref lines row).text (max col s-col))))
                                    (setf col (min col s-col))
                                    (setf s-col col)
                                    (touch (aref lines row)))
                                  (let ((r0 (min row s-row))
                                        (r1 (max row s-row))
                                        (c0 (if (< row s-row) col s-col))
                                        (c1 (if (< row s-row) s-col col)))
                                    (setf (aref lines r0).text
                                          (+ (slice (aref lines r0).text 0 c0)
                                             (slice (aref lines r1).text c1)))
                                    (splice lines (1+ r0) (- r1 r0))
                                    (setf row r0)
                                    (setf col c0)
                                    (setf s-row row)
                                    (setf s-col col)
                                    (touch (aref lines row))))))
    (dolist (L (split content "\n"))
      (let ((line (append-child screen (create-element "div"))))
        (set-style line
                   whiteSpace "pre")
        (setf line.textContent (+ L " "))
        (push (new-line L line) lines)))
    (setf screen."data-resize" #'update)
    (set-handler screen onscroll (update))
    (set-handler document.body onmousewheel
                 (let ((delta (floor (/ event.wheelDelta -60)))
                       (screen-lines (floor (/ screen.offsetHeight ch))))
                   (setf top (max 0 (min (+ top delta) (- (length lines) screen-lines)))))
                 (update))
    (set-handler document.body onkeydown
                 (let ((block true))
                   (case event.which
                     (33
                      (let ((delta (floor (/ screen.offsetHeight ch))))
                        (decf top delta)
                        (decf row delta)))
                     (34
                      (let ((delta (floor (/ screen.offsetHeight ch))))
                        (incf top delta)
                        (incf row delta)))
                     (35
                      (when event.ctrlKey
                        (setf row (1- (length lines))))
                      (setf col (length (aref lines row).text)))
                     (36
                      (when event.ctrlKey
                        (setf row 0))
                      (setf col 0))
                     (37
                      (if (> col 0)
                          (decf col)
                          (when (> row 0)
                            (decf row)
                            (setf col (length (aref lines row).text)))))
                     (39
                      (if (< col (length (aref lines row).text))
                          (incf col)
                          (when (< row (1- (length lines)))
                            (incf row)
                            (setf col 0))))
                     (40
                      (if (< row (1- (length lines)))
                          (progn
                            (incf row)
                            (when (> col (length (aref lines row).text))
                              (setf col (length (aref lines row).text))))
                          (setf col (length (aref lines row).text))))
                     (38
                      (if (> row 0)
                          (progn
                            (decf row)
                            (when (> col (length (aref lines row).text))
                              (setf col (length (aref lines row).text))))
                          (setf col 0)))
                     (46
                      (when (and (= row s-row) (= col s-col))
                        (if (< s-col (length (aref lines row).text))
                            (incf s-col)
                            (when (< s-row (1- (length lines)))
                              (incf s-row)
                              (setf s-col 0))))
                      (delete-selection))
                     (8
                      (if (and (= row s-row) (= col s-col))
                          (if (> col 0)
                              (let ((line (aref lines row)))
                                (decf col)
                                (setf line.text
                                      (+ (slice line.text 0 col)
                                         (slice line.text (1+ col))))
                                (touch line))
                              (when (> row 0)
                                (let ((line (aref lines row))
                                      (prev-line (aref lines (1- row))))
                                  (setf col (length prev-line.text))
                                  (incf prev-line.text line.text)
                                  (splice lines row 1)
                                  (touch prev-line)
                                  (decf row))))
                          (delete-selection)))
                     (13
                      (let ((line (aref lines row))
                            (newline (new-line (slice (aref lines row).text col))))
                        (setf line.text (slice line.text 0 col))
                        (incf row)
                        (insert lines row newline)
                        (setf col 0)
                        (let ((indent (length (first ((regexp "^ *").exec line.text)))))
                          (when (> indent 0)
                            (setf newline.text
                                  (+ (slice line.text 0 indent)
                                     newline.text))
                            (incf col indent)))
                        (touch line)
                        (touch newline)))
                     (otherwise
                      (setf block false)))
                   (when block
                     (event.preventDefault)
                     (event.stopPropagation)
                     (unless event.shiftKey
                       (setf s-row row)
                       (setf s-col col))
                     (fix))))
    (set-handler document.body onkeypress
                 (event.preventDefault)
                 (event.stopPropagation)
                 (delete-selection)
                 (let ((line (aref lines row)))
                   (setf line.text
                         (+ (slice line.text 0 col)
                            (char event.which)
                            (slice line.text col)))
                   (incf col)
                   (setf s-row row)
                   (setf s-col col)
                   (touch line)
                   (fix)))
    (set-handler screen onmousedown
                 (labels ((pos (x y)
                               (let (((x0 y0) (element-pos screen)))
                                 (decf x x0)
                                 (decf y y0)
                                 (if (and (< 0 x screen.clientWidth)
                                          (< 0 y screen.clientHeight))
                                     (let ((a (max 0 (min (1- (length lines)) (+ (floor (/ y ch)) top)))))
                                       (list a (max 0 (min (floor (/ x cw)) (length (aref lines a).text)))))
                                     (list null null)))))
                   (let (((r c) (apply #'pos (event-pos event))))
                     (unless (null? r)
                       (event.preventDefault)
                       (event.stopPropagation)
                       (setf row r)
                       (setf col c)
                       (setf s-row r)
                       (setf s-col c)
                       (fix)
                       (let* ((scroller-delta 0)
                              (scroller (set-interval (lambda ()
                                                        (incf top scroller-delta)
                                                        (incf row scroller-delta)
                                                        (fix))
                                                      20)))
                         (tracking (lambda (x y)
                                     (let (((r c) (pos x y)))
                                       (if (null? r)
                                           (let (((sx sy) (element-pos screen))
                                                 (sh screen.offsetHeight))
                                             (when (< y sy)
                                               (setf scroller-delta (floor (/ (- y sy) ch))))
                                             (when (> y (+ sy sh))
                                               (setf scroller-delta (1+ (floor (/ (- y (+ sy sh)) ch))))))
                                           (progn
                                             (setf scroller-delta 0)
                                             (setf row r)
                                             (setf col c)
                                             (fix)))))
                                   (lambda () (clear-interval scroller))))))))
    (set-timeout #'fix 10)
    screen))

(defun test-editor ()
  (let** ((w (window 0 0 640 480 title: "Editor test"))
          (editor (add-widget w (editor (replace (http-get "bbchess64k.c") "\r" "")))))
    (set-layout w (V border: 8 spacing: 8
                     (dom editor)))
    (show-window w center: true)))

(defun test-editor-fs ()
  (let ((editor (editor (replace (http-get "bbchess64k.c") "\r" ""))))
    (set-style editor
               position "absolute"
               px/left 8
               px/top 8
               px/bottom 8
               px/right 8)
    (append-child document.body editor)))

(defun main ()
  (test-editor))

(main)