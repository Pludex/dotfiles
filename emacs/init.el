;;; init.el -*- lexical-binding: t; -*-

(doom! :input

       :completion
       (corfu +orderless)
       vertico

       :ui
       doom
       !modeline
       ophints
       (popup +defaults)

       :editor
       (evil +everywhere)
       file-templates
       fold

       :emacs
       dired
       electric
       undo
       vc

       :term
       vterm

       :checkers
       syntax

       :tools
       (lsp +eglot)
       magit

       :os
       (:if IS-MAC macos)

       :lang
       emacs-lisp
       (org +pretty)

       :config
       (default +bindings +smartparens))
