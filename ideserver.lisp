(import * from rpc-server)

(rpc:defun login (user-name)
  (open-session user-name))

(defun authorized (proplist tokens)
  (when proplist
    (dolist (t (append (list "admin") tokens))
      (when (find t proplist)
        (return-from authorized true))))
  false)

(defun auth (proplist &rest tokens)
  (unless (authorized proplist tokens)
    (error "Authorization required")))

(rpc:defun rget-file (user-name session-id filename authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* filename))
        "read")
  (try (get-file filename) null))

(rpc:defun rput-file (user-name session-id filename content authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* (list filename content)))
        "write")
  (put-file filename content)
  true)

(rpc:defun rlist-files (user-name session-id path authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* path))
        "list")
  ((node:require "fs").readdirSync path))

(rpc:defun rping (user-name session-id authcode)
  (check-authorization user-name session-id authcode "null"))

(defvar *processes* #())
(defvar *process-id* 0)
(defobject process (proc user-name output exit-code))

(rpc:defun rterminal (user-name session-id authcode)
  (auth (check-authorization user-name session-id authcode "null")
        "terminal")
  (let* ((proc ((node:require "child_process").spawn
                "/usr/bin/script"
                (list "-q" "-f" "/dev/null")
                #((stdio "pipe"))))
         (output (list))
         (p (new-process proc user-name output null))
         (id (incf *process-id*)))
    (proc.stdout.on "data" (lambda (data)
                             (push (data.toString "utf-8") output)))
    (proc.stderr.on "data" (lambda (data)
                             (push (data.toString "utf-8") output)))
    (proc.on "exit" (lambda (code)
                      (display ~"Terminal {id} ({user-name}) exit-code: {code}")
                      (setf p.exit-code code)))
    (setf (aref *processes* id) p)
    (display ~"Started terminal {id} ({user-name})")
    id))

(rpc:defun rterminal-send (user-name session-id id x authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* (list id x)))
        "terminal")
    (when (and (aref *processes* id)
               (= user-name (aref *processes* id).user-name))
      (let ((p (aref *processes* id)))
        (when (null? p.exit-code)
          (p.proc.stdin.write x)))))

(rpc:defun rterminal-receive (user-name session-id id authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* id))
        "terminal")
  (when (and (aref *processes* id)
             (= user-name (aref *processes* id).user-name))
    (let ((p (aref *processes* id)))
      (list p.exit-code (splice p.output)))))

(rpc:defun rterminal-detach (user-name session-id id authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* id))
        "terminal")
  (when (and (aref *processes* id)
             (= user-name (aref *processes* id).user-name))
    (display ~"Detaching terminal {id} ({user-name})")
    (remove-key *processes* id)))

(defun load-users ()
  (let ((file (try (get-file "ide-users")
                   (progn
                     (display "*** WARNING: no ide-users file; using default ***")
                     "admin/-1390728475/admin\n"))))
    (dolist (line (split file "\n"))
      (when line
        (let (((user secret permissions) (split line "/")))
          (setf (aref rpc-server:*users* user)
                (rpc-server:new-user user secret (split permissions ","))))))))

(defun save-users ()
  (put-file "ide-users"
            (+ (join (map (lambda (name)
                            (let* ((u (aref rpc-server:*users* name))
                                   (perms (join u.permissions ",")))
                              ~"{u.name}/{u.secret}/{perms}"))
                          (keys rpc-server:*users*))
                     "\n")
               "\n")))

(rpc:defun set-user-secret (user-name session-id newsecret authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* newsecret))
        "read" "write" "terminal" "list")
  (setf (aref rpc-server:*users* user-name).secret newsecret)
  (save-users)
  true)

(rpc:defun add-user (user-name session-id newuser newsecret permissions authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* (list newuser newsecret permissions)))
        "admin")
  (when (aref rpc-server:*users* newuser)
    (error "User already defined"))
  (setf (aref rpc-server:*users* newuser)
        (rpc-server:new-user newuser newsecret permissions))
  (save-users)
  true)

(rpc:defun remove-user (user-name session-id user authcode)
  (auth (check-authorization user-name session-id authcode
                             (json* user))
        "admin")
  (unless (aref rpc-server:*users* user)
    (error "User not found"))
  (remove-key rpc-server:*users* user)
  (save-users)
  true)

(rpc:defun list-users (user-name session-id authcode)
  (auth (check-authorization user-name session-id authcode "null")
        "admin")
  (map (lambda (name)
         #((name name)
           (permissions (aref rpc-server:*users* name).permissions)))
       (keys rpc-server:*users*)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar address "127.0.0.1")
(defvar port 1337)

(defun main ()
  (load-users)
  (display ~"Serving {address}:{port}")
  (start-server address port))

(main)
