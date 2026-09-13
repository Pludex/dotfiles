{ pkgs, ... }:
{

  earlyInit = ''
    ;;; early-init.el --- Emacs initialization -*- lexical-binding: t; -*-
  '';

  extraPackages = [ ];
  packagesFile = ./packages.el;

  package = pkgs.emacs-pgtk;
}
