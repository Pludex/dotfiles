;;; ui.el --- Emacs initialization -*- lexical-binding: t; -*-

(set-face-attribute 'default nil
                    :font "FiraCode Nerd Font"
                    :height 90
                    :weight 'normal)

(add-to-list 'custom-theme-load-path (expand-file-name "lisp/ui/theme" user-emacs-directory))
(load-theme 'carbonfox t)

(set-frame-parameter nil 'alpha-background 50)
(add-to-list 'default-frame-alist '(alpha-background . 50))

(setq-default fringe-mode 15)
(set-frame-parameter nil 'internal-border-width 10)
(add-to-list 'default-frame-alist '(internal-border-width . 10))
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
(setq inhibit-splash-screen t)

(scroll-bar-mode -1)
(tool-bar-mode -1)
(tooltip-mode -1)
(menu-bar-mode -1)

(provide 'ui)
;;; ui.el ends here
