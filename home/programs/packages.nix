{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    treefmt
    sops
    jq
    file
    wifitui
    fzf
    grc
    libnotify
  ];
}
