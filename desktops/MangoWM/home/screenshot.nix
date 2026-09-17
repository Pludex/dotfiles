{ pkgs, lib, ... }:
{
  programs.mango.settings.bind = [
    "SUPER+SHIFT,S,spawn,${lib.getExe pkgs.myPkgs.screenshot}"
  ];
}
