{ pkgs, lib, ... }:
{
  programs.mango.settings.bind = [
    "SUPER+CTRL,S,spawn,${lib.getExe pkgs.myPkgs.screenrecord}"
  ];

}
