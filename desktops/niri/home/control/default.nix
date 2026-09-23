{ pkgs, ... }:
{
  home.packages = [
    pkgs.sway-audio-idle-inhibit
  ];
  imports = [
    ./binds.nix
  ];
}
