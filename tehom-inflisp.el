;;; tehom-inflisp.el --- Additions to comint to support rtest

;; Copyright (C) 2000 by Tom Breton

;; Author: Tom Breton <tob@world.std.com>
;; Keywords: extensions, lisp

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; 

;;; Code:


;;;;;;;;;;;;;;
;;Requirements
(require 'comint)
(require 'inf-lisp)

;;It's in ancillary if needed.  Provides `comint-redirect-completed'.
(if (not (fboundp 'comint-redirect-send-command-to-process))
  (require 'comint-redirect))  


;;;;;;;;;;;
;;Constants
(defconst tehom-inflisp-redirect-timeout-msecs 50 "" )


;;;;;;;;;;;
;;Utility functions

(defun tehom-read-multiple (&optional stream)
  ""
  (let
    ( a
      (collected '())
      (done nil))
    (while
      (not done)
      ;;Easiest way to find out when read can't read anything more
      ;;is to let it try and catch its error.
      (condition-case err
	(setq a (read stream))
	(error (setq done t)))

      ;;This has to be outside the condition-case, otherwise it
      ;;gets messed up on the final iteration.
      (unless done
	(push a collected)))
	
    (nreverse collected)))

(eval-when-compile
  (setf
    (get 'tehom-read-multiple 'rtest-suite)
    '("tehom-read-multiple"
       
       ( "Read multiple values given by a string"
	 (with-temp-buffer
	   (erase-buffer)
	   (insert "0 1 2")
  
	   (goto-char 1)
	   (tehom-read-multiple (current-buffer)))

	 '(0 1 2))

       )))


;;;;;;;;;;;;;;;;;;;
;;Helper functions


;;;;;;
;;Functions to do funcalls between Elisp and the inferior lisp process.

;;Adapted from comint-redirect-results-list-from-process; Thanks, Peter.
(defun tehom-redirect-read-from-process 
  (process command-string reader)
  "Send COMMAND-STRING to PROCESS. 
Read the results with READER and return whatever READER returns."

  (let ((output-buffer " *Comint Redirect Work Buffer*"))
    
    (save-excursion
      (set-buffer (get-buffer-create output-buffer))
      (erase-buffer)
      (comint-redirect-send-command-to-process
	command-string
	output-buffer
	process
	nil
	t
	)
      ;; Wait for the process to complete
      (set-buffer (process-buffer process))
      (while (null comint-redirect-completed)
	(accept-process-output nil 0 tehom-inflisp-redirect-timeout-msecs))
      
      ;; Collect the output
      (set-buffer output-buffer)
      (goto-char (point-min))
      ;; Skip past the command-string, if it was echoed
      (and (looking-at command-string)
	(forward-line))

      ;;Call a reader function, whose results are returned.
      (funcall reader (current-buffer)))))

(eval-when-compile
  (setf
    (get 'tehom-redirect-read-from-process 'rtest-suite)
    '("tehom-redirect-read-from-process"

       ( "Read a single value from the lisp process"
	 (tehom-redirect-read-from-process
	   (inferior-lisp-proc) 
	   "(car '(54))"
	   #'read)

	 54)

       ( "Read a single value, when multiple values are returned"
	 (tehom-redirect-read-from-process
	   (inferior-lisp-proc) 
	   "(values 0 1 2)"
	   #'read)

	 0)

       ("Read multiple values"
	 (tehom-redirect-read-from-process
	   (inferior-lisp-proc) 
	   "(values 0 1 2)"
	   #'tehom-read-multiple)

	 '(0 1 2))

       )))


(defun tehom-inflisp-read (command reader)
  ""

  (tehom-redirect-read-from-process 
    (inferior-lisp-proc) (format "%S" command) reader))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Entry points

;;;###autoload
(defun tehom-inflisp-eval-void (form)
  "Evaluate `FORM' in the inferior lisp, always returning nil."

  (comint-simple-send (inferior-lisp-proc) (format "%S" form))
  nil)

;;Because it always tells Elisp it got nil, there's not much we can do
;;to automatically test it.

;;;###autoload
(defun tehom-inflisp-eval (form)
  "Evaluate `FORM' in the inferior lisp, returning a single value."

  (tehom-inflisp-read form #'read))

(eval-when-compile
  (setf
    (get 'tehom-inflisp-eval 'rtest-suite)
    '("tehom-inflisp-eval"

       ( 
	 (tehom-inflisp-eval
	   '(car '(54)))
	 '54)

       ("If multiple values are returned, the first one is used."
	 (tehom-inflisp-eval
	   '(values 0 1 2))
	 0)
       
       )))


;;;###autoload
(defun tehom-inflisp-eval-multiple-value-list (form)
  "Evaluate `FORM' in the inferior lisp, returning multiple values.

Conceptually, this is like:
  \(multiple-value-list
    \(tehom-inflisp-eval FORM... \)\)
which wouldn't actually work."

  (tehom-inflisp-read form #'tehom-read-multiple))

(eval-when-compile
  (setf
    (get 'tehom-inflisp-eval-multiple-value-list 'rtest-suite)
    '("tehom-inflisp-eval-multiple-value-list"
       ( "Returns multiple values in order."
	 (tehom-inflisp-eval-multiple-value-list
	   '(values 0 1 2))
	 '(0 1 2))

       )))


(eval-when-compile

  (setf
    (get 'rtest-cl-entry-rtest-active 'rtest-suite)
    '("rtest-cl-entry-rtest-active.
These tests require an inferior lisp process to be running.  They are
fairly slow, so if you think this has stalled, it may not have."

       tehom-redirect-read-from-process
       tehom-read-multiple
       tehom-inflisp-eval-void
       tehom-inflisp-eval
       tehom-inflisp-eval-multiple-value-list

       )))

(provide 'tehom-inflisp)

;;; tehom-inflisp.el ends here