;;; init.el --- Emacs initialization -*- lexical-binding: t; -*-

(require 'use-package)

(load (concat (file-name-directory load-file-name) "packages.el"))

(load (concat (file-name-directory load-file-name) "core/core.el"))
(load (concat (file-name-directory load-file-name) "ui/ui.el"))

(require 'ui)
(require 'core)

(setq use-package-always-ensure t)

(vertico-mode 1)
(marginalia-mode 1)
