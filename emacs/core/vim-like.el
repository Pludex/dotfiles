;;; vim-like.el --- Emacs initialization -*- lexical-binding: t; -*-

(setq evil-want-integration t
      evil-want-keybinding nil)
(use-package evil
  :init
  (setq evil-want-C-u-scroll t
        evil-want-C-i-jump nil
        evil-respect-visual-line-mode t)
  :config
  (evil-mode 1)

  (setq evil-normal-state-cursor '(box "cyan")
        evil-insert-state-cursor '(bar "cyan")
        evil-visual-state-cursor '(hollow "cyan"))

  ; (use-package evil-escape
    ; :init (evil-escape-mode 1)
    ; :config
    ; (setq evil-escape-key-sequence "jk"
          ; evil-escape-delay 0.3))

  (use-package evil-collection
    :after evil
    :config
    (evil-collection-init))

  (use-package evil-surround
    :config (global-evil-surround-mode 1))

  (use-package evil-commentary
    :config (evil-commentary-mode 1))

  (use-package evil-matchit
    :config (global-evil-matchit-mode 1)))

(provide 'vim-like)
