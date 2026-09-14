{ pkgs, ... }:
{
  programs.doom-emacs = {
    doomDir = ./.;
    emacs = pkgs.emacs-pgtk;
  };
}
