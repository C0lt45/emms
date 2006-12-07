;;; emms-i18n.el --- Function for handling coding system

;; Copyright 2006 Ye Wenbin
;;
;; Author: wenbinye@163.com
;; Keywords: 
;; X-URL: not distributed yet

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; When read from process, first check the CAR part of
;; `emms-default-coding-system', if non-nil, use this for decode, and
;; nerver detect coding system, if nil, first call
;; `emms-coding-dectect-functions' to get coding system, if success,
;; decode the result, otherwise, use `emms-detect-coding-function',
;; the emacs detect coding function, if the coding detected is not in
;; `emms-nerver-used-coding-system', decode it, otherwise use
;; locale-coding-system.
;;
;; When write send data to process, first check the CDR part of
;; `emms-default-coding-system', if non-nil, use this to encode data,
;; otherwise do nothing, that means use `default-process-coding-system' or
;; `process-coding-system-alist' to encode data.

;; Put this file into your load-path and the following into your ~/.emacs:
;;   (require 'emms-i18n)

;;; Code:

(provide 'emms-i18n)
(eval-when-compile
  (require 'cl))

(defun emms-iconv (from to str)
  "Convert STR from FROM coding to TO coding."
  (if (and from to)
      (decode-coding-string
       (encode-coding-string str to)
       from)
    str))

(defun emms-iconv-region (beg end from to)
  (when (and from to)
    (save-restriction
      (narrow-to-region beg end)
      (encode-coding-region (point-min) (point-max) to)
      (decode-coding-region (point-min) (point-max) from))))

(defun emms-iconv-buffer (from to &optional buf)
  (save-excursion
    (and buf (set-buffer buf))
    (emms-iconv-region (point-min) (point-max) from to)))

(defun emms-set-default-coding-system (read-coding write-coding)
  "Set `emms-default-coding-system'"
  (interactive "zSet coding system for read: \nzSet coding system for write: ")
  (setq emms-default-coding-system
        (cons
         (and (coding-system-p read-coding) read-coding)
         (and (coding-system-p write-coding) write-coding)))
  (message (concat
            (if (car emms-default-coding-system)
                (format "The coding system for read is %S." (car emms-default-coding-system))
              "Good, you want detect coding system by me!")
            (format " The coding system for write is %S."
                    (or (cdr emms-default-coding-system)
                        (cdr default-process-coding-system))))))

(defun emms-call-process-simple (&rest args)
  "This function run program and return the program result. If the CAR
part of `emms-default-coding-system' is non-nil, the program result will
be decode use the CAR part of emms-default-coding-system. Otherwise,
use `emms-coding-dectect-functions' to detect the coding system of the
result. If the emms-coding-dectect-functions failed, use
`emms-detect-coding-function' to detect coding system. If all the
coding system is nil or in `emms-nerver-used-coding-system', decode
the result using `emms-coding-system-for-read'.

The rest arguments ARGS is as the same as `call-process', except the
BUFFER should always have value t. Otherwise the coding detection will
not perform."
  (let ((default-process-coding-system (copy-tree default-process-coding-system))
        (process-coding-system-alist nil) exit pos)
    (when (eq (nth 2 args) 't)
      (setcar default-process-coding-system (car emms-default-coding-system))
      (setq pos (point)))
    (setq exit (apply 'call-process args))
    (when (and (eq (nth 2 args) 't)
               (null (car emms-default-coding-system)))
      (save-restriction
        (narrow-to-region pos (point))
        (decode-coding-region (point-min) (point-max) (emms-detect-buffer-coding-system))))
    exit))

;; Is this function useful?
(defun emms-call-process (&rest args)
  "Run the program like `call-process'. If
the cdr part `emms-default-coding-system' is non-nil, the string in
ARGS will be encode by the CDR part of `emms-default-coding-system',
otherwise, it is pass all parameter to `call-process'."
  (with-temp-buffer
    (if (cdr emms-default-coding-system)
        (let ((default-process-coding-system emms-default-coding-system)
              (process-coding-system-alist nil))
          (apply 'call-process args))
      (apply 'call-process args))))
  
(defvar emms-nerver-used-coding-system
  '(raw-text undecided)
  "If the `emms-coding-dectect-functions' return coding system in
this list, use `emms-default-coding-system' instead.")

(defvar emms-coding-system-for-read 'utf-8
  "If coding detect failed, use this for decode")

(defvar emms-default-coding-system nil
  "If non-nil, used for decode and encode")

(defvar emms-coding-dectect-functions nil
  "A list of function to call to detect codings")

(defvar emms-detect-max-size 10000
  "Max bytes to detect coding system. Nil mean scan whole buffer.")

(defun emms-detect-coding-function (size)
  (detect-coding-region (point)
                        (+ (if (null emms-detect-max-size)
                               size
                             (min size emms-detect-max-size))
                           (point)) t))

(defun emms-detect-buffer-coding-system (&optional buf)
  "Before call this function, make sure the buffer is literal"
  (let ((size (- (point-max) (point-min)))
        (func (append emms-coding-dectect-functions 'emms-detect-coding-function))
        coding)
    (save-excursion
      (and buf (set-buffer buf))
      (goto-char (point-min))
      (when (> size 0)
        (setq coding (run-hook-with-args-until-success 'func size))
        (if (member (coding-system-base coding) emms-nerver-used-coding-system)
            (setq coding (emms-detect-coding-function size))))
      (if (or (null coding) (member (coding-system-base coding) emms-nerver-used-coding-system))
          emms-coding-system-for-read
        coding))))

;;; emms-i18n.el ends here
