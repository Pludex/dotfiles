;;; ui.el --- Emacs initialization -*- lexical-binding: t; -*-

(defvar ui/
  (file-name-directory
   (or load-file-name buffer-file-name ".")))

;;
;;; Frame / window chrome

(add-to-list 'default-frame-alist '(alpha-background . 50))
(set-frame-parameter (selected-frame) 'alpha-background 50)

(set-frame-parameter nil 'internal-border-width 10)
(add-to-list 'default-frame-alist '(internal-border-width . 10))
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;;
;;; Startup screen

(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
(setq inhibit-splash-screen t)

;;
;;; Fonts

(set-face-attribute 'default nil
                     :font "FiraCode Nerd Font"
                     :height 90
                     :weight 'normal)

;;
;;; Theme

(add-to-list 'custom-theme-load-path (expand-file-name "themes" ui/))
(setq doom-theme 'carbonfox)

;;
;;; Evil cursor

(setq evil-normal-state-cursor '(box "#78A9FF")
      evil-insert-state-cursor '(bar "#78A9FF")
      evil-visual-state-cursor '(hollow "#78A9FF"))

;;
;;; Line highlighting

(global-hl-line-mode +1)
(after! hl-line
  (set-face-background 'hl-line "#2a2a2a"))

;;
;;; modeline

(load (expand-file-name "modeline.el" ui/) t)

;;
;;; dashboard

(after! doom-dashboard
  (set-face-background 'doom-dashboard-banner nil)
  (set-face-background 'doom-dashboard-loaded nil)
  (set-face-background 'doom-dashboard-menu-title nil)
  (set-face-background 'doom-dashboard-menu-desc nil)
  (set-face-background 'doom-dashboard-footer nil))
