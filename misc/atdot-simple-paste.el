;; atdot-simple-paste.el -- Post snippet to simplepaste

;; Copyright (C) 2011  Kazuhiro NISHIYAMA

;; Author: Kazuhiro NISHIYAMA
;; Keywords: comm, data

;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
;; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
;; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
;; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(require 'url)

(defvar atdot-simple-paste-auto-commit-terminator
  "http://www.atdot.net/sp/view/"
  "sp/commit/autoが必ず返す文字列の一部")
(defvar atdot-simple-paste-auto-commit-url
  "http://www.atdot.net/sp/commit/auto"
  "sp/commit/autoのURL")
(defvar atdot-simple-paste-auto-commit-result-regexp
  "http://www\\.atdot\\.net/sp/view/[a-z0-9]+"
  "sp/commit/autoでpasteした結果を表示するためのURLを取り出す正規表現")
(defvar atdot-simple-paste-languages-alist
  '(("Plain" . "")
    ("ActionScript3" . "as3")
    ("Bash/shell" . "bash")
    ("C#" . "c-sharp")
    ("C++" . "cpp")
    ("CSS" . "css")
    ("ColdFusion" . "cf")
    ("Delphi" . "delphi")
    ("Diff" . "diff")
    ("Erlang" . "erl")
    ("Groovy" . "groovy")
    ("Java" . "java")
    ("JavaFX" . "jfx")
    ("JavaScript" . "js")
    ("PHP" . "php")
    ("Perl" . "perl")
    ("Plain Text" . "plain")
    ("PowerShell" . "ps")
    ("Python" . "py")
    ("Ruby" . "ruby")
    ("SQL" . "sql")
    ("Scala" . "scala")
    ("Visual Basic" . "vb")
    ("XML" . "xml")
    )
  ;; 「ruby -I. -r syntax_highlighter -e 'SH_LANG_NAMES.each{|k,v|puts %Q(    ("#{k}" . "#{v}"))}' | sort」で更新
  "simplepaste が language で受け付けるもの一覧")

(defvar atdot-simple-paste-mode-to-languages-alist
  '((sh-mode . "Bash/shell")
    (c++-mode . "C++")
    (c-mode . "C++")
    (diff-mode . "Diff")
    (java-mode . "Java")
    (js-mode . "JavaScript")
    (perl-mode . "Perl")
    (python-mode . "Python")
    (sql-mode . "SQL")
    (ruby-mode . "Ruby")
    (nxml-mode . "XML"))
  "major-mode から language への一覧")


(defun atdot-simple-paste-post ()
  "リージョンかバッファの内容を貼り付けて URL をキルリングに入れる。"
  (interactive)
  (call-interactively
   (if (and transient-mark-mode mark-active)
       'atdot-simple-paste-post-region
     'atdot-simple-paste-post-buffer)))

(defun atdot-simple-paste-post-buffer ()
  "バッファの内容を http://www.atdot.net/sp/ に貼り付けて URL をキルリングに入れる。"
  (interactive)
  (atdot-simple-paste-post-with-read
   (buffer-substring (point-min) (point-max))))

(defun atdot-simple-paste-post-region (beg end)
  "リージョンを http://www.atdot.net/sp/ に貼り付けて URL をキルリングに入れる。"
  (interactive "r")
  (atdot-simple-paste-post-with-read
   (buffer-substring beg end)))

(defun atdot-simple-paste-post-with-read (paste_body &optional args)
  "Title と Language を読み込んでから貼り付ける。"
  (let* ((default-title (buffer-name))
         (title (read-string
                 (format "Title (default %s): " default-title)
                 nil nil default-title))
         (default-language
           (or
            (cdr (assoc
                  major-mode
                  atdot-simple-paste-mode-to-languages-alist))
            (caar atdot-simple-paste-languages-alist)))
         (language
          (cdr (assoc
                (let ((completion-ignore-case t))
                  (completing-read
                   (format "Language (default %s): "
                           default-language)
                   atdot-simple-paste-languages-alist
                   nil t nil nil default-language))
                atdot-simple-paste-languages-alist))))
    (if language
        (setq args (cons `("language" . ,language) args)))
    (if title
        (setq args (cons `("title" . ,title) args)))
    (setq args (cons `("paste_body" . ,paste_body) args))
    (atdot-simple-paste-post-internal args)))

(defun atdot-simple-paste-post-internal (args)
  (let ((url-request-method "POST")
	(url-request-extra-headers
	 '(("Content-Type" . "application/x-www-form-urlencoded")))
	(url-request-data
	 (mapconcat (lambda (arg)
		      (concat (url-hexify-string (car arg))
			      "="
			      (url-hexify-string (cdr arg))))
		    args
		    "&")))
    (url-retrieve atdot-simple-paste-auto-commit-url
		  'atdot-simple-paste-parse-url-buffer)
    ))

(defun atdot-simple-paste-parse-url-buffer (status)
  (kill-new
   (save-excursion
     ;;(switch-to-buffer (current-buffer))
     (goto-char (point-min))
     (if (re-search-forward atdot-simple-paste-auto-commit-result-regexp
			    nil t)
	 (match-string 0)
       (error "Paste failed."))))
   (message "Pasted to <%s>" (car kill-ring)))

;;; Local Variables:
;;; mode: emacs-lisp
;;; coding: utf-8
;;; indent-tabs-mode: nil
;;; End:
