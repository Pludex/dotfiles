;;; config.el --- Emacs initialization -*- lexical-binding: t; -*-

(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                          ("elpa" . "https://elpa.gnu.org/org/")
                          ("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)

(unless (package-installed-p 'autothemer)
  (package-refresh-contents)
  (package-install 'autothemer))
(require 'autothemer)

(add-to-list 'custom-theme-load-path (file-name-directory load-file-name))
(load-theme 'nightfox t)

(scroll-bar-mode -1)
(tool-bar-mode -1)
(tooltip-mode -1)
(set-fringe-mode 10)
(menu-bar-mode -1)

(require 'evil)
(evil-mode 1)

(vertico-mode 1)
(marginalia-mode 1)
