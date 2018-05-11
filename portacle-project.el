(provide 'portacle-project)
(setq project-default-licence "BSD-3")

(defun replace-project-variables (string &optional vars)
  (let ((vars '(user-full-name user-mail-address
                project-name project-description
                project-licence year month day))
        (year (format-time-string "%Y"))
        (month (format-time-string "%m"))
        (day (format-time-string "%d"))
        ;; Case-sensitive regexp mathcing
        (case-fold-search nil))
    (dolist (var vars string)
      (setq string (replace-regexp-in-string (upcase (symbol-name var)) (symbol-value var) string t t)))))

(defun maybe-update-quicklisp-db ()
  (interactive)
  (cond ((slime-connected-p)
         (message "Updating Quicklisp DB...")
         (slime-eval '(ql:register-local-projects))
         (message "Quicklisp DB updated."))
        (t
         (message "Slime not connected, cannot update."))))

(defun --copy-project-internal (from to)
  (make-directory to t)
  (dolist (template (directory-files from))
    (unless (or (string= template ".")
                (string= template ".."))
      (let ((srcfile (concat from "/" template))
            (destfile (concat to "/" (replace-project-variables template))))
        (cond ((file-directory-p srcfile)
               (--copy-project-internal srcfile destfile))
              (t
               (portacle-fwrite (replace-project-variables (portacle-fread srcfile))
                                destfile)))))))

(cl-defun create-project (&key name description licence)
          (interactive)
          (let* ((project-name (or name (read-string "Project name: ")))
                 (project-description (or description (read-string "Project description: ")))
                 (project-licence (or licence (read-string "Project licence: " project-default-licence)))
                 (dir (portacle-path (concat "projects/" project-name)))
                 (skeleton (portacle-path "config/skeleton/")))
            (cond ((file-exists-p dir)
                   (message "A project with that name already exists."))
                  (t
                   (message "Creating project skeleton...")
                   (--copy-project-internal skeleton dir)
                   (magit-init dir)
                   (maybe-update-quicklisp-db)
                   (message "Project created.")))))

(defun clone-project (&optional url name)
  (interactive)
  (let* ((url (or url (read-string "Project URL: ")))
         (path (url-filename (url-generic-parse-url url)))
         (name (or name (car (last (split-string path "/")))))
         (dir (portacle-path (concat "projects/" name))))
    (cond ((file-exists-p dir)
           (message "A project with that name already exists."))
          (t
           (message "Cloning project...")
           (magit-clone url dir)
           (maybe-update-quicklisp-db)
           (message "Project cloned.")))))

(defun remove-project (&optional name)
  (interactive)
  (let* ((name (or name (read-string "Project name: ")))
         (dir (portacle-path (concat "projects/" name))))
    (cond ((file-exists-p dir)
           (message "Deleting project directory...")
           (delete-directory dir t)
           (maybe-update-quicklisp-db)
           (message "Project removed."))
          (t
           (message "No such project found.")))))

;; Configuration of user variables
;; This kinda fuckin' sucks, I should rewrite it sometime.
(cl-defun portacle-configure (&key name email licence)
  (interactive)
  (let ((name (or name (read-string "Your name: " user-full-name)))
        (email (or email (read-string "Your e-mail address: " user-mail-address)))
        (licence (or licence (read-string "Default project licence: " project-default-licence))))
    (call-process magit-git-executable nil nil t "config" "--file" (portacle-path "config/git/config") "user.name" name)
    (call-process magit-git-executable nil nil t "config" "--file" (portacle-path "config/git/config") "user.email" email)
    (portacle-fwrite (prin1-to-string `(setq user-full-name ,name)) (portacle-path "config/user.el") t)
    (portacle-fwrite "\n" (portacle-path "config/user.el") t)
    (portacle-fwrite (prin1-to-string `(setq user-mail-address ,email)) (portacle-path "config/user.el") t)
    (portacle-fwrite "\n" (portacle-path "config/user.el") t)
    (portacle-fwrite (prin1-to-string `(setq project-default-licence ,licence)) (portacle-path "config/user.el") t)
    (portacle-fwrite "\n" (portacle-path "config/user.el") t)
    (portacle-fwrite (prin1-to-string `(setq portacle-setup-done-p t)) (portacle-path "config/user.el") t)
    (setq user-full-name name)
    (setq user-mail-address email)
    (setq project-default-licence licence)
    (setq portacle-setup-done-p t)
    (message "User information set.")))
