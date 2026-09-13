;;; init.el --- Emacs initialization -*- lexical-binding: t; -*-

(require 'use-package)
(setq use-package-always-ensure t)

(use-package autothemer)

(add-to-list 'custom-theme-load-path (file-name-directory load-file-name))
(load-theme 'nightfox t)

(scroll-bar-mode -1)
(tool-bar-mode -1)
(tooltip-mode -1)
(set-fringe-mode 10)
(menu-bar-mode -1)

(use-package evil
  :config
  (evil-mode 1))

(use-package vertico
  :config
  (vertico-mode 1))

(use-package marginalia
  :config
  (marginalia-mode 1))
