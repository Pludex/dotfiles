{ pkgs, ... }:
{
  packages = with pkgs.firefoxAddons; [
    ublock-origin
    darkreader
    bitwarden-password-manager

    material-icons-for-github

    enhancer-for-youtube
    yt-block
  ];
}
