;;; ui.el --- Emacs initialization -*- lexical-binding: t; -*-

(add-to-list 'custom-theme-load-path (expand-file-name "lisp/ui/theme" user-emacs-directory))

(load-theme 'carbonfox t)

(scroll-bar-mode -1)
(tool-bar-mode -1)
(tooltip-mode -1)
(set-fringe-mode 10)
(menu-bar-mode -1)

(provide 'ui)
;;; ui.el ends here
