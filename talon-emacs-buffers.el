;; -*- lexical-binding: t -*-
(require 'cl)
(require 'cl-macs)
(require 'pcase)

(defmacro measure-time (&rest body)
  "Measure the time it takes to evaluate BODY."
  `(let ((time (current-time)))
     (prog1 (progn ,@body)
       (message "%.06f" (float-time (time-since time))))))

(defvar *talon-updating-buffers* nil)
(defvar *talon-buffer-list-path* "~/.emacs.d/talon-buffer-list")
(defvar *talon-buffers* (make-hash-table :test 'equal))
(defvar talon-buffer-cache (make-hash-table :test 'eq))
(defvar talon-reswitch-buffers nil)
(defvar talon-reswitch-keys "abcd")

(add-hook 'buffer-list-update-hook 'talon-update-buffers-callback)
;(remove-hook 'buffer-list-update-hook 'talon-update-buffers-callback)

;;; KEY MAP ;;;
(define-prefix-command 'talon-prefix 'talon-prefix-map)
(global-set-key '[f12] 'talon-prefix)
(define-key talon-prefix-map "b" 'talon-switch)
(define-key talon-prefix-map "o" 'talon-switch-other-window)
(define-key talon-prefix-map "a" 'talon-reswitch)


;;; SWITCHING ;;;
(defun talon-switch (spoken-form &optional switching-function)
  (interactive "sSpoken form: ")
  (unless switching-function (setq switching-function 'switch-to-buffer))
  ;; We find the buffers matching the spoken form, sorted by most recently
  ;; visited. The only way to know what's recently visited is the order of the
  ;; buffer list, so this amounts to filtering the buffer list down to those
  ;; that match the spoken form.
  (pcase (let ((candidates (remq (current-buffer)
                                 (gethash spoken-form *talon-buffers*))))
           (seq-filter (lambda (b) (memq b candidates)) (buffer-list)))
    ('nil (message "No such buffer!"))
    ;; Switch to the first matching buffer and display the rest (if any) so the
    ;; user can change their mind.
    (`(,buffer . ,rest)
     (funcall switching-function buffer)
     (when rest
       ;; Remember the matches for talon-reswitch.
       (setq talon-reswitch-buffers rest)
       ;; Display the most recent of the other matches, with letters attached
       ;; for quick switching.
       (let ((shortlist (cl-mapcar 'cons talon-reswitch-keys rest)))
         (message
          (concat (apply 'propertize "Or  %s" minibuffer-prompt-properties)
                  (and (< (length talon-reswitch-keys) (length rest))
                       #("  [!] more..." 2 13 (face (:foreground "dark red")))))
          (mapconcat 'talon-format-reswitch-buffer shortlist "  ")))))
    ;; ;; If there's a unique matching buffer, switch to it.
    ;; (`(,buffer) (funcall switching-function buffer))
    ;; ;; If there aren't many alternatives, optimistically switch to the first
    ;; ;; and display the others so the user can change their mind.
    ;; ((and `(,buffer . ,rest)
    ;;       (guard (<= (length rest) (length talon-reswitch-keys))))
    ;;  (funcall switching-function buffer)
    ;;  (setq talon-reswitch-buffers (cl-mapcar 'cons talon-reswitch-keys rest))
    ;;  (message (apply 'propertize "Or  %s" minibuffer-prompt-properties)
    ;;           (mapconcat 'talon-format-reswitch-buffer talon-reswitch-buffers "  ")))
    ;; ;; Otherwise, let the user select a buffer.
    ;; (buffers
    ;;  (funcall
    ;;   switching-function
    ;;   (ido-completing-read "Buffer: " (mapcar 'buffer-name buffers) nil 'confirm)))
    ))

(defun talon-switch-other-window (spoken-form)
  (interactive "sSpoken form: ")
  (talon-switch spoken-form 'switch-to-buffer-other-window))

;;; RESWITCHING ;;;
(defun talon-reswitch (key)
  (interactive "c")
  ;; Bang ('!') means to list all possible matching buffers.
  (if (eql ?! key)
      (let ((names (mapcar 'buffer-name talon-reswitch-buffers)))
        (switch-to-buffer (ido-completing-read "Buffer: " names nil 'confirm)))
   (pcase (assoc key (cl-mapcar 'cons talon-reswitch-keys talon-reswitch-buffers))
     ('nil (message "No such buffer!"))
     (`(,_ . ,b) (switch-to-buffer b)))))

(defun talon-format-reswitch-buffer (entry)
  (destructuring-bind (char . buffer) entry
    (format #("[%c] %s" 0 4 (face (:foreground "dark red")))
            char
            (buffer-name buffer))))


;;; SPOKEN FORMS ;;;
;;; FIXME: need to lowercase all spoken forms
(defun talon-buffer-spoken-forms (buffer)
  (talon-spoken-forms (buffer-name buffer) (buffer-file-name buffer)))

(iter-defun talon-spoken-forms (buffer-name file-name)
  (dolist (name (cons buffer-name
                      (and file-name
                           (list (file-name-base file-name)
                                 (file-name-nondirectory file-name)))))
    (let ((spoken-list (talon-speechify name)))
      (iter-yield (mapconcat 'identity spoken-list " "))))
  ;; consecutive subsequences of lengths 2-5
  (cl-loop for x on (talon-speechify buffer-name)
           while (cdr x)
           do (iter-yield (mapconcat 'identity (seq-take x 2) " "))
           when (cddr x) do (iter-yield (mapconcat 'identity (seq-take x 3) " "))
           when (cdddr x) do (iter-yield (mapconcat 'identity (seq-take x 4) " "))
           when (cddddr x) do (iter-yield (mapconcat 'identity (seq-take x 5) " "))
           )
  ;; ;;; all subsequences of lengths 2-4
  ;; (dolist (spoken-list (talon-subsequences 2 5 (talon-speechify buffer-name)))
  ;;   (iter-yield (mapconcat 'identity spoken-list " ")))
  )

(defun talon-subsequences (min-length max-length list)
  (let* ((vector (make-vector (1+ max-length) nil)))
    (aset vector 0 '(nil))
    (dolist (elt (reverse list))
     (cl-loop
      for i from max-length downto 1
      do (aset vector i
               (nconc
                (cl-loop for r in (aref vector (- i 1))
                         collect (cons elt r))
                (aref vector i)))))
    (cl-loop for i from min-length to max-length
             nconc (aref vector i))))

(defun talon-reject-spoken-form-p (spoken-form)
  (or
   (>= 3 (length spoken-form))
   (member spoken-form '("" "back" "last" "more"))))

;;; Example: (talon-speechify "dir/Foo-BAR.py")
;;;      --> ("dir" "foo" "bar" "dot py")
(defconst talon-spoken-part "\\(\\.*\\)\\([a-zA-Z]+\\)")
(defun talon-speechify (input)
  (let ((start 0))
   (cl-loop for pos = (string-match talon-spoken-part input start)
            while pos
            collect (let ((dots (match-string 1 input))
                          ;; make sure all components are lowercase
                          (word (downcase (match-string 2 input))))
                      (concat
                       (apply 'concat (make-list (length dots) "dot "))
                       word))
            do (setf start (match-end 0)))))

;(defun talon-speechify (input) (split-string input "[^a-zA-Z]" t))


;;; UPDATING THE BUFFER LIST ;;;
(defun talon-update-buffers-callback ()
  ;; FIXME: is this `unless' necessary/useful/harmful?
  (unless *talon-updating-buffers*
   (run-with-idle-timer 0 nil 'talon-update-buffers)))

;; (defun talon-update-buffers (&optional force)
;;   (interactive "P")
;;   ;; avoid recursive invocation problems
;;   (unless *talon-updating-buffers*
;;     ;; (message "updating talon buffers...")
;;     (progn ;measure-time/progn
;;       (catch 'talon-update-buffers
;;         (measure-time ;measure-time/progn
;;          (let ((*talon-updating-buffers* t)
;;                ;; reverse order so that when we add them to the index the most
;;                ;; recent buffers end up at the front of the lists.
;;                (buffer-list (nreverse (buffer-list))))
;;            ;; 1. Update talon-buffer-cache, which maps live, non-temporary buffers
;;            ;; to (name . file-name) pairs. We use this to detect whether anything
;;            ;; we depend on has changed, which can rule out the need for further
;;            ;; computation. First, we remove deleted or temporary buffers.
;;            (let ((state-changed nil))
;;              (cl-loop for b in (cl-loop
;;                                 for b being the hash-keys of talon-buffer-cache
;;                                 when (or (not (buffer-live-p b))
;;                                          (string-prefix-p " " (buffer-name b)))
;;                                 collect b)
;;                       do (setq state-changed t) (remhash b talon-buffer-cache))
;;              ;; Second, we check for buffers whose name or file name has changed, or
;;              ;; newly created buffers.
;;              (dolist (b buffer-list)
;;                (let ((name (buffer-name b))
;;                      (file-name (buffer-file-name b))
;;                      (entry (gethash b talon-buffer-cache)))
;;                  (unless (string-prefix-p " " name)
;;                    (unless (and (equal name (car entry))
;;                                 (equal file-name (cdr entry)))
;;                      (setq state-changed t)
;;                      (puthash b (cons name file-name) talon-buffer-cache)))))
;;              ;; If nothing changed, than we have nothing to do.
;;              (unless (or state-changed force)
;;                (throw 'talon-update-buffers nil)))

;;            ;; 2. Update the mapping from spoken forms to buffers.
;;            (clrhash *talon-buffers*)
;;            (dolist (b buffer-list)
;;              ;; exclude temporary buffers (whose names start with a space)
;;              (unless (string-prefix-p " " (buffer-name b))
;;                (iter-do (spoken-form (talon-buffer-spoken-forms b))
;;                  (unless (talon-reject-spoken-form-p spoken-form)
;;                    ;; associate spoken-form with b in *talon-buffers*
;;                    (puthash spoken-form
;;                             (cons b (delq b (gethash spoken-form *talon-buffers*)))
;;                             *talon-buffers*)))))

;;            ;; 3. Update the talon buffer list file.
;;            (message "UPDATING TALON BUFFERS")
;;            (with-temp-file *talon-buffer-list-path*
;;              (maphash '(lambda (spoken-form _)
;;                          (insert (format "%s\n" spoken-form)))
;;                       *talon-buffers*))))))))

(defun talon-update-buffers (&optional force)
  (interactive "P")
  ;; avoid recursive invocation problems
  (unless *talon-updating-buffers*
    (progn ;measure-time/progn
      ;(message "updating talon buffers...")
      ;; To force regenerating spoken forms, we nuke our state.
      (when force
        (clrhash *talon-buffers*)
        (clrhash talon-buffer-cache))
      (let ((*talon-updating-buffers* t)
            (buffer-list (buffer-list))
            (updated nil)
            (removed (cl-loop
                      for b being the hash-keys of talon-buffer-cache
                      when (or (not (buffer-live-p b))
                               (string-prefix-p " " (buffer-name b)))
                      collect b)))
        ;; 1. Calculate which buffers have been updated or added.
        (dolist (b buffer-list)
          (let ((entry (gethash b talon-buffer-cache)))
            (unless (string-prefix-p " " (buffer-name b))
              (unless (and (equal (car entry) (buffer-name b))
                           (equal (cdr entry) (buffer-file-name b)))
                (push b updated)))))

        ;; 2. Update state.
        (dolist (b removed)
          (destructuring-bind (name . file-name) (gethash b talon-buffer-cache)
            ;; remove the corresponding spoken forms.
            (remhash b talon-buffer-cache)
            (iter-do (spoken-form (talon-spoken-forms name file-name))
              (let ((bs (delq b (gethash spoken-form *talon-buffers*))))
                (if bs (puthash spoken-form bs *talon-buffers*)
                  (remhash spoken-form *talon-buffers*))))))

        (dolist (b updated)
          (let ((name (buffer-name b))
                (file-name (buffer-file-name b)))
            (puthash b (cons name file-name) talon-buffer-cache)
            (iter-do (spoken-form (talon-spoken-forms name file-name))
              (unless (talon-reject-spoken-form-p spoken-form)
                (let ((bs (gethash spoken-form *talon-buffers*)))
                  (unless (memq b bs)
                    (puthash spoken-form (cons b bs) *talon-buffers*)))))))

        ;; 3. Update the talon buffer list file if necessary.
        (when (or updated removed)
          ;;(message "UPDATING TALON BUFFERS")
          (with-temp-file *talon-buffer-list-path*
            (maphash '(lambda (spoken-form _)
                        (insert (format "%s\n" spoken-form)))
                     *talon-buffers*)))))))

(talon-update-buffers t)

(provide 'talon-emacs-buffers)
