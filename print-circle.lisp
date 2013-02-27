(defvar *read-backpointers* #())

(defun set-mark-reader (src)
  (do ((name ""))
      ((find (current-char src) '("=" "#" undefined))
         (if (= (current-char src) "#")
             (progn
               (next-char src)
               (aref *read-backpointers* name))
             (progn
               (next-char src)
               (skip-spaces src)
               (if (= (current-char src) "(")
                   (let ((result (setf (aref *read-backpointers* name) (list))))
                     (next-char src)
                     (skip-spaces src)
                     (do ()
                         ((or (= (current-char src) ")")
                              (undefined? (current-char src)))
                            (next-char src)
                            result)
                       (push (read src) result)
                       (skip-spaces src)))
                   (setf (aref *read-backpointers* name)
                         (read src))))))
    (incf name (current-char src))
    (next-char src)))

(progn
  (setf (hash-reader "0") #'set-mark-reader)
  (setf (hash-reader "1") #'set-mark-reader)
  (setf (hash-reader "2") #'set-mark-reader)
  (setf (hash-reader "3") #'set-mark-reader)
  (setf (hash-reader "4") #'set-mark-reader)
  (setf (hash-reader "5") #'set-mark-reader)
  (setf (hash-reader "6") #'set-mark-reader)
  (setf (hash-reader "7") #'set-mark-reader)
  (setf (hash-reader "8") #'set-mark-reader)
  (setf (hash-reader "9") #'set-mark-reader))

(defvar *print-circle* false)
(defvar *print-width* 70)

(defun pprint (obj)
  (let ((seen (list))
        (loops (list))
        (sent (list))
        (result "")
        (col 0)
        (row 0)
        (indent (list)))
    (labels ((visit (x)
               (when (list? x)
                 (if (find x seen)
                     (unless (find x loops)
                       (push x loops))
                     (progn
                       (push x seen)
                       (dolist (y x)
                         (visit y))))))
             (newline ()
               (incf result "\n")
               (dotimes (i (last indent))
                 (incf result " "))
               (incf row)
               (setf col (last indent)))
             (output (str)
               (when (and (= (first str) "\n")
                          (> (length str) 1))
                 (newline)
                 (setf str (slice str 1)))
               (case str
                 ("\n"
                    (newline))
                 ("("
                    (incf result str)
                    (incf col)
                    (push col indent))
                 (")"
                    (incf result str)
                    (incf col)
                    (pop indent))
                 (otherwise
                    (when (and (> col (last indent))
                               (> (+ col (length str)) *print-width*))
                      (newline))
                    (incf result str)
                    (incf col (length str)))))
             (sep (ppx px x i)
               (cond
                 ((list? (first x)) "\n")
                 ((= (first x) 'progn) "\n ")
                 ((= (first x) 'do) (cond
                                      ((= i 0) " ")
                                      ((= i 1) "\n   ")
                                      (true "\n ")))
                 ((= (first x) 'cond) "\n ")
                 ((= (first x) 'case) (if (>= i 1) "\n " " "))
                 ((= (first x) 'and) (if (>= i 1) "\n    " " "))
                 ((= (first x) 'or) (if (>= i 1) "\n   " " "))
                 ((= (first x) 'enumerate) (if (>= i 1) "\n " " "))
                 ((= (first x) 'defun) (if (>= i 2) "\n " " "))
                 ((= (first x) 'defmacro) (if (>= i 2) "\n " " "))
                 ((= (first x) 'if) (if (>= i 1) "\n   " " "))
                 ((= (first x) 'let) (if (>= i 1) "\n " " "))
                 ((= (first x) 'let*) (if (>= i 1) "\n " " "))
                 ((= (first x) 'let**) (if (>= i 1) "\n " " "))
                 ((= (first px) 'cond) "\n")
                 ((= (first px) 'case) "\n")
                 ((= (first ppx) 'labels) (if (>= i 1) "\n " " "))
                 ((= (first ppx) 'macrolet) (if (>= i 1) "\n " " "))
                 ((= (first x) 'when) (if (>= i 1) "\n " " "))
                 (true " ")))
             (dumplist (ppx px x)
               (enumerate (j y x)
                 (dump px x y)
                 (when (< j (1- (length x)))
                   (output (sep ppx px x j)))))
             (dump (ppx px x)
               (cond
                 ((list? x)
                  (let ((ix (1+ (index x loops))))
                    (if (> ix 0)
                        (if (find x sent)
                            (output ~"#{ix}#")
                            (progn
                              (output ~"#{ix}=(")
                              (push x sent)
                              (dumplist ppx px x)
                              (output ")")))
                        (progn
                          (output "(")
                          (dumplist ppx px x)
                          (output ")")))))
                 ((symbol? x)
                  (output (symbol-name x)))
                 (true
                  (output (json x))))))
      (when *print-circle* (visit obj))
      (dump (list) (list) obj)
      (display result)
      null)))
