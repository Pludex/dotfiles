{ pkgs, base, ... }:
{
  home.packages = [
    pkgs.wl-clipboard
  ];

  imports = [ "${base.commonDesktop}/clipse.nix" ];

  programs.mango.settings.bind = [
    "SUPER,V,spawn,kitty --class clipse -e clipse"
  ];
  wayland.windowManager.mango.settings.windowrule = [
    "isfloating:1,width:600,height:650,appid:clipse"
  ];
}
