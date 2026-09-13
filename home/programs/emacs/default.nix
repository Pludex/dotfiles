{
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.use-package
      epkgs.vertico
      epkgs.orderless
      epkgs.marginalia
      epkgs.magit
      epkgs.evil
      epkgs.autothemer
    ];
  };

  xdg.configFile."emacs/init.el".text = ''
    ;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-
    (load "${./cfg}/config.el")
  '';
}
