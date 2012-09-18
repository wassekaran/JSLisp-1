(import * from gui)
(import * from layout)

(defun char-cell (element)
  (let ((x (append-child element (create-element "div"))))
    (set-style x
               position "absolute"
               whiteSpace "pre"
               display "hidden"
               px/left 0
               px/top 0)
    (setf x.textContent "XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX\n\
                         XXXXXXXXXX")
    (let ((result (list (/ x.offsetWidth 10)
                        (/ x.offsetHeight 10))))
      (remove-child element x)
      result)))

(defun signature (d)
  (+ "{"
     (join (map (lambda (k)
                  ~"{k}:{(json (aref d k))}")
                (sort (keys d)))
           ",")
     "}"))

(defobject line
    (text
     div
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
       (setf i (length text))
       (unless (= (aref text (1- i)) "\\")
         (setf ec.preproc false)))
      ((= (slice text i (+ i 2)) "/*")
       (setf ec.mlcomment true))
      ((= (aref text i) "#")
       (setf ec.preproc true))
      ((or (= (aref text i) ".")
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
                (push (new-section i0 i #((font-weight "bold")
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

(defun compute-html (text sections)
  (let ((res "")
        (i 0))
    (dolist (s sections)
      (when (< i s.from)
        (incf res (htm (slice text i s.from)))
        (setf i s.from))
      (incf res "<span style=\"")
      (incf res (join (map (lambda (k)
                             ~"{k}:{(aref s.style k)}")
                           (keys s.style))
                      "; "))
      (incf res ~"\">")
      (incf res (htm (slice text s.from s.to)))
      (incf res "</span>")
      (setf i s.to))
    (when (< i (length text))
      (incf res (htm (slice text i))))
    ~"<span style=\"background-color:#FFFFFF\">{res}</span>"))

(defun editor (content)
  (let** ((screen (set-style (create-element "div")
                            fontFamily "Droid Sans Mono"
                            backgroundColor "#FFFFFF"
                            px/fontSize 16
                            px/padding 4
                            px/marginLeft -4
                            px/marginTop -4
                            overflow "auto"))
          (lines (list))
          (cw null)
          (ch null)
          (last-width null)
          (last-height null)
          (row 0)
          (col 0)
          (s-row 0)
          (s-col 0)
          (cursor (append-child screen (set-style (create-element "div")
                                                  position "absolute"
                                                  backgroundColor "#FF0000"
                                                  px/width 3
                                                  px/height 12)))
          (#'touch (line)
                   (setf line.start-signature null))
          (#'update ()
                    (let ((cr 0))
                      (do () ((or (>= cr (length lines))
                                  (>= (+ (aref lines cr).div.offsetTop
                                         (aref lines cr).div.offsetHeight)
                                      screen.scrollTop)))
                        (incf cr))
                      (do () ((or (>= cr (length lines))
                                  (>= (aref lines cr).div.offsetTop
                                      (+ screen.scrollTop
                                         screen.offsetHeight))))
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
                              (setf line.end-signature (signature line.end-context))
                              (let ((h (compute-html text line.sections)))
                                (if (> x1 (length text))
                                    (setf h (+ "<div style=\"position:relative; background-color:#FFFF00\">&nbsp;"
                                               "<div style=\"position:absolute; left:0px; top:0px\">"
                                               h
                                               "</div></div>"))
                                    (when (= text "")
                                      (incf h "&nbsp;")))
                                (setf line.div.innerHTML h))))
                          (incf cr)))))
          (#'fix ()
                 (let ((sw screen.offsetWidth)
                       (sh screen.offsetHeight))
                   (when (or (/= sw last-width)
                             (/= sh last-height))
                     (setf last-width sw)
                     (setf last-height sh)
                     (let (((ccw cch) (char-cell screen)))
                       (setf cw ccw)
                       (setf ch cch))
                     (setf cursor.style.height ~"{(+ ch 2)}px"))
                   (let ((line (aref lines row)))
                     (set-style cursor
                                px/top (1+ line.div.offsetTop)
                                px/left (+ 3 (* col cw))))
                   (when (> (- cursor.offsetTop screen.scrollTop)
                            (+ screen.offsetTop screen.offsetHeight -30))
                     (setf screen.scrollTop
                           (- cursor.offsetTop screen.offsetHeight -30)))
                   (when (< cursor.offsetTop screen.scrollTop)
                     (setf screen.scrollTop cursor.offsetTop)))
                 (update)))
    (dolist (L (split content "\n"))
      (let ((line (append-child screen (create-element "div"))))
        (set-style line
                   whiteSpace "pre")
        (setf line.textContent (+ L " "))
        (push (new-line L line) lines)))
    (setf screen."data-resize" #'update)
    (set-handler screen onscroll (update))
    (set-handler document.body onkeydown
      (let ((block true))
        (case event.which
          (33
             (let ((y (- (aref lines row).div.offsetTop
                         screen.offsetHeight)))
               (do () ((or (= row 0)
                           (< (aref lines row).div.offsetTop y)))
                 (decf row))
               (setf col (min col (length (aref lines row).text)))))
          (34
             (let ((y (+ (aref lines row).div.offsetTop
                         screen.offsetHeight)))
               (do () ((or (= row (1- (length lines)))
                           (> (aref lines row).div.offsetTop y)))
                 (incf row))
               (setf col (min col (length (aref lines row).text)))))
          (35
             (setf col (length (aref lines row).text)))
          (36
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
          (8
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
                     (remove-child screen line.div)
                     (splice lines row 1)
                     (touch prev-line)
                     (decf row)))))
          (13
             (let ((line (aref lines row))
                   (newline (set-style (create-element "div")
                                       whiteSpace "pre")))
               (setf newline (new-line (slice line.text col) newline))
               (setf line.text (slice line.text 0 col))
               (append-child screen newline.div line.div.nextSibling)
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
    (set-handler screen onmousedown
      (labels ((pos (x y)
                    (let (((x0 y0) (element-pos screen)))
                      (decf x x0)
                      (decf y y0)
                      (if (and (< 0 x screen.clientWidth)
                               (< 0 y screen.clientHeight))
                          (progn
                            (incf y screen.scrollTop)
                            (do ((a 0)
                                 (b (length lines)))
                                ((>= a (1- b))
                                   (setf a (max 0 (min a (1- (length lines)))))
                                   (list a (max 0 (min (floor (/ x cw)) (length (aref lines a).text)))))
                              (let ((t (ash (+ a b) -1)))
                                (if (< y (aref lines t).div.offsetTop)
                                    (setf b t)
                                    (setf a t)))))
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
            (tracking (lambda (x y)
                        (let (((r c) (pos x y)))
                          (unless (null? r)
                            (setf row r)
                            (setf col c)
                            (fix)))))))))
    (set-handler document.body onkeypress
      (event.preventDefault)
      (event.stopPropagation)
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
  (test-editor-fs))

(main)