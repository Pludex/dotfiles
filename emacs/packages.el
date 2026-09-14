;;; packages.el --- Emacs initialization -*- lexical-binding: t; -*-

;; UI
(use-package autothemer :ensure t)
(use-package doom-modeline :ensure t)
(use-package comet-trail :ensure t)

;; core
(setq evil-want-integration t
      evil-want-keybinding nil)
(use-package evil :ensure t)
(use-package evil-escape :ensure t )
(use-package evil-collection :ensure t)
(use-package evil-surround :ensure t)
(use-package evil-commentary :ensure t)
(use-package evil-matchit :ensure t)

(use-package vertico :ensure t)
(use-package marginalia :ensure t)
