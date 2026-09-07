{ pkgs, ... }:
{
  home.packages = [
    pkgs.myPkgs.wps
  ];
}
