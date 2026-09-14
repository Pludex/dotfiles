;;; carbonfox-theme.el --- A port of nightfox.nvim's carbonfox variant -*- lexical-binding: t; -*-

;;; Commentary:
;; A dark, Carbon-inspired theme, ported from nightfox.nvim (carbonfox flavour).

;;; Code:

(require 'autothemer)

(autothemer-deftheme carbonfox "A port of nightfox.nvim (carbonfox variant)"

  ;; Specify the color classes used by the theme
  ((((class color) (min-colors #xFFFFFF))
    ((class color) (min-colors #xFF)))

   ;; Palette: each color needs one value per class declared above
   (nightfox-bg      "#161616" "#000000")
   (nightfox-fg      "#f2f4f8" "#ffffff")

   (nightfox-black   "#282828" "#262626")
   (nightfox-white   "#dfdfe0" "#d0d0d0")
   (nightfox-red     "#EE5396" "#d75f87")
   (nightfox-green   "#25be6a" "#00af5f")
   (nightfox-blue    "#78A9FF" "#5fafff")
   (nightfox-purple  "#BE95FF" "#af87ff")
   (nightfox-yellow  "#08BDBA" "#00afaf")
   (nightfox-orange  "#3DDBD9" "#5fd7d7")
   (nightfox-cyan    "#33B1FF" "#00afff")
   (nightfox-pink    "#FF7EB6" "#ff87af")

   (nightfox-region  "#2a2a2a" "#262626")
   (nightfox-comment "#525253" "#585858"))

  ;; Specifications for Emacs faces.
  ((default (:foreground nightfox-fg :background nightfox-bg))

   ;; Programming ;;
   (font-lock-string-face        (:foreground nightfox-green))
   (font-lock-keyword-face       (:foreground nightfox-purple))
   (font-lock-type-face          (:foreground nightfox-yellow))
   (font-lock-variable-name-face (:foreground nightfox-white))
   (font-lock-comment-face       (:foreground nightfox-comment))
   (font-lock-builtin-face       (:foreground nightfox-red))
   (font-lock-constant-face      (:foreground nightfox-orange))
   (font-lock-function-name-face (:foreground nightfox-blue))
   (font-lock-preprocessor-face  (:foreground nightfox-pink))
   (font-lock-operator-face      (:foreground nightfox-green))

   ;; General ;;
   (error   (:foreground nightfox-red))
   (warning (:foreground nightfox-purple))
   (info    (:foreground nightfox-blue))

   ;; UI ;;
   (region                  (:background nightfox-region))
   (mode-line               (:foreground nightfox-fg :background nightfox-bg))
   (line-number-current-line (:foreground nightfox-purple))
   (line-number             (:foreground nightfox-comment)))

  ;; Forms evaluated after face specs; palette vars available with comma.
  (custom-theme-set-variables 'carbonfox
    `(ansi-color-names-vector
      [,nightfox-black ,nightfox-red ,nightfox-green ,nightfox-yellow
       ,nightfox-blue ,nightfox-purple ,nightfox-cyan ,nightfox-white])))

(provide-theme 'carbonfox)
(provide 'carbonfox-theme)
;;; carbonfox-theme.el ends here
