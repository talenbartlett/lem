(defpackage :lem.auto-save
  (:use :cl :lem)
  (:export :*make-backup-files*))
(in-package :lem.auto-save)

(define-editor-variable auto-save-checkpoint-frequency 5)
(define-editor-variable auto-save-key-count-threshold 256)

(defvar *make-backup-files* nil)
(defvar *timer* nil)

(define-minor-mode auto-save-mode
    (:name "AS")
  (enable))

(defun auto-save-filename (buffer)
  (format nil "~A~~" (buffer-filename buffer)))

(defun checkpoint-buffer (buffer)
  (when (and (buffer-filename buffer)
             (buffer-modified-p buffer))
    (when (mode-active-p buffer 'auto-save-mode)
      (write-to-file buffer (buffer-filename buffer))
      (buffer-unmark buffer)
      (when *make-backup-files*
        (message "Auto save from ~A to ~A" (buffer-name buffer) (auto-save-filename buffer))
        (write-to-file buffer (auto-save-filename buffer))))))

(defun checkpoint-all-buffers ()
  (dolist (buffer (buffer-list))
    (when (buffer-modified-p buffer)
      (checkpoint-buffer buffer))))

(defun count-keys (key)
  (declare (ignore key))
  (let* ((buffer (current-buffer))
         (count (incf (buffer-value buffer 'key-count 0)))
         (threshold (variable-value 'auto-save-key-count-threshold)))
    (when (<= threshold count)
      (setf (buffer-value buffer 'key-count) 0)
      (checkpoint-buffer buffer))))

(defun enable ()
  (unless *timer*
    (let ((interval (variable-value 'auto-save-checkpoint-frequency)))
      (when (and (numberp interval) (plusp interval))
        (setf *timer* (start-idle-timer (* interval 1000) t 'checkpoint-all-buffers
                                        (lambda (condition)
                                          (pop-up-backtrace condition)
                                          (disable)) "autosave"))))
    (add-hook *input-hook* 'count-keys)))

(defun disable ()
  (when *timer*
    (stop-timer *timer*)
    (setf *timer* nil)
    (remove-hook *input-hook* 'count-keys)))

(define-command toggle-auto-save () ()
  (if *timer*
      (disable)
      (enable)))
