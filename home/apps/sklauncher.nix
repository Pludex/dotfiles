{ pkgs, ... }:
{
  home.packages = with pkgs; [
    myPkgs.sklauncher
  ];
}
