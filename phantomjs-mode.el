;;; Main Function

;;;###autoload
(define-derived-mode phantomjs-mode js-mode "PhantomJS"
  "Major mode for editing PhantomJS scripts."
  :group 'js
)

;;;###autoload

(provide 'phantomjs)
(require 'websocket)

(defconst phantomjs-mode-base (file-name-directory load-file-name))
(defcustom phantomjs-binary "phantomjs" "The phantomjs binary to invoke")

(defvar phantomjs-server nil)
(defvar phantomjs-outgoing-messages nil)
(defvar phantomjs-awaiting-response nil)
(defvar phantomjs-client nil)

(defun phantomjs-connect ()
  (unless (eq (process-status "PHANTOMJS") 'run) ; Either the user killed the process
					; or something else did. Either way need to start afresh
    (when phantomjs-server
      (websocket-server-close phantomjs-server)
      (setq phantomjs-server '()))
    (when phantomjs-client
      (websocket-close phantomjs-client)
      (setq phantomjs-client '()))
    (setq phantomjs-outgoing-messages nil)
    (setq phantomjs-awaiting-response nil))
  (when (null phantomjs-server)
    (setq phantomjs-server
	  (websocket-server t
			    :on-message (lambda (w m)
					  (if
					      (null phantomjs-awaiting-response)
					      (warn "Response received when no request was sent")
					    (save-excursion
					      (set-buffer (cadr phantomjs-awaiting-response))
					      (goto-char (cddr phantomjs-awaiting-response))
					      (insert (concat "\n" (websocket-frame-payload m))))
					    (setq phantomjs-awaiting-response '())
					    (phantomjs-dispatch))
					  )
			    :on-open (lambda (w)
				       (setq phantomjs-client w)
				       (phantomjs-dispatch)))) ;No authentification at the moment
    (setenv "PHANTOMJS_COMM_PORT" (format "%d" (process-contact phantomjs-server :service)))
    
    (make-comint-in-buffer "PHANTOMJS" nil phantomjs-binary nil (expand-file-name "phantom-repl.js" phantomjs-mode-base))
    ))

(defun phantomjs-dispatch ()
  (when (and (null phantomjs-awaiting-response)
	     (not (null phantomjs-client))
	     (not (null phantomjs-outgoing-messages)))
    (let (
	  (msg (car phantomjs-outgoing-messages))
	  (remaining (cdr phantomjs-outgoing-messages)))
      (websocket-send-text phantomjs-client (car msg))
      (setq phantomjs-awaiting-response msg)
      (setq phantomjs-outgoing-messages remaining))))

(defun phantomjs-eval (start end)
  "Evaluate the region in PhantomJS"
  (interactive "r")
  (phantomjs-connect)
  (setq phantomjs-outgoing-messages
	(append phantomjs-outgoing-messages (list (cons
					     (buffer-substring-no-properties start end)
					     (cons (current-buffer) end)))))
  (phantomjs-dispatch))
