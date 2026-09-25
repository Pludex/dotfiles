{ pkgs, ... }:
let
  volume-control = pkgs.myPkgs.volume-control;
  brightness-control = pkgs.myPkgs.brightness-control;
  player-control = "${pkgs.playerctl}/bin/playerctl";
in
{
  programs.mango.settings.bind = [
    "NONE,XF86AudioRaiseVolume,spawn,${volume-control}/bin/volume-control --inc"
    "NONE,XF86AudioLowerVolume,spawn,${volume-control}/bin/volume-control --dec"
    "NONE,XF86AudioMute,spawn,${volume-control}/bin/volume-control --toggle"
    "NONE,XF86AudioMicMute,spawn,${volume-control}/bin/volume-control --toggle-mic"

    "NONE,XF86AudioPlay,spawn,${player-control} --player=spotify play-pause"
    "NONE,XF86AudioStop,spawn,${player-control} --player=spotify stop"
    "NONE,XF86AudioPrev,spawn,${player-control} --player=spotify previous"
    "NONE,XF86AudioNext,spawn,${player-control} --player=spotify next"

    "NONE,XF86MonBrightnessUp,spawn,${brightness-control}/bin/brightness-control --inc"
    "NONE,XF86MonBrightnessDown,spawn,${brightness-control}/bin/brightness-control --dec"

    "NONE,XF86HomePage,spawn,${brightness-control}/bin/brightness-control --inc"
    "NONE,XF86Mail,spawn,${brightness-control}/bin/brightness-control --dec"
  ];
}
