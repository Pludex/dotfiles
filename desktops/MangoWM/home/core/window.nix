{ config, ... }:
{
  programs.mango.settings.bind = [
    "SUPER,Q,killclient"

    "SUPER,H,focusdir,left"
    "SUPER,L,focusdir,right"
    "SUPER,K,focusdir,up"
    "SUPER,J,focusdir,down"

    "SUPER+SHIFT,H,move_client,left"
    "SUPER+SHIFT,L,move_client,right"
    "SUPER+SHIFT,K,move_client,up"
    "SUPER+SHIFT,J,move_client,down"

    "SUPER,Tab,toggleoverview"

    "SUPER,1,view,1"
    "SUPER,2,view,2"
    "SUPER,3,view,4"
    "SUPER,4,view,8"
    "SUPER,5,view,16"
    "SUPER,6,view,32"
    "SUPER,7,view,64"
    "SUPER,8,view,128"
    "SUPER,9,view,256"

    "SUPER+SHIFT,1,tag,1"
    "SUPER+SHIFT,2,tag,2"
    "SUPER+SHIFT,3,tag,4"
    "SUPER+SHIFT,4,tag,8"
    "SUPER+SHIFT,5,tag,16"
    "SUPER+SHIFT,6,tag,32"
    "SUPER+SHIFT,7,tag,64"
    "SUPER+SHIFT,8,tag,128"
    "SUPER+SHIFT,9,tag,256"
  ];

  wayland.windowManager.mango.settings = {
    focuscolor = "0x${config.lib.stylix.colors.base0D}ff";
    bordercolor = "0x${config.lib.stylix.colors.base02}ff";
    rootcolor = "0x${config.lib.stylix.colors.base00}ff";

    borderpx = 2;

    blur = 1;
    blur_optimized = 1;
    blur_params = {
      radius = 5;
      num_passes = 2;
    };
    border_radius = 6;

    focused_opacity = 1.0;
    sloppyfocus = 0;
  };
}
