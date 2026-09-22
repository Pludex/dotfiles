{ pkgs, base, ... }:
let
  zoxidePaths = [
    base.abs.home
    "${base.abs.home}/.config"

    "/workspaces"
    base.abs.dotfiles
    base.abs.dotfilesBot
  ];
in
{
  programs.zoxide = {
    enable = true;
  };

  home.activation.seedZoxide = ''
    ${builtins.concatStringsSep "\n" (map (path: "${pkgs.zoxide}/bin/zoxide add ${path}") zoxidePaths)}
  '';
}
