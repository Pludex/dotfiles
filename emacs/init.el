;;; init.el --- Emacs initialization -*- lexical-binding: t; -*-

(require 'use-package)

(load (concat (file-name-directory load-file-name) "packages.el"))

(load (concat (file-name-directory load-file-name) "ui/ui.el"))

(require 'ui)

(setq use-package-always-ensure t)

(evil-mode 1)
(vertico-mode 1)
(marginalia-mode 1)
