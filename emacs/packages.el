;;; packages.el --- Emacs initialization -*- lexical-binding: t; -*-

(setq use-package-always-ensure nil)

;; UI
(use-package autothemer)

;; core
(setq evil-want-integration t
      evil-want-keybinding nil)
(use-package evil)
(use-package evil-escape)
(use-package evil-collection)
(use-package evil-surround)
(use-package evil-commentary)
(use-package evil-matchit)

(use-package vertico)
(use-package marginalia)
