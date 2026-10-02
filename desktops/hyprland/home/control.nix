{ pkgs, ... }:
let
  volume-control = pkgs.myPkgs.volume-control;
  brightness-control = pkgs.myPkgs.brightness-control;
  player-control = "${pkgs.playerctl}/bin/playerctl";
in
{
  programs.hyprland.settings.binds = {
    "XF86AudioRaiseVolume".dsp.exec_cmd = "${volume-control}/bin/volume-control --inc";
    "XF86AudioLowerVolume".dsp.exec_cmd = "${volume-control}/bin/volume-control --dec";
    "XF86AudioMute".dsp.exec_cmd = "${volume-control}/bin/volume-control --toggle";
    "XF86AudioMicMute".dsp.exec_cmd = "${volume-control}/bin/volume-control --toggle-mic";

    "XF86AudioPlay".dsp.exec_cmd = "${player-control} --player=spotify play-pause";
    "XF86AudioStop".dsp.exec_cmd = "${player-control} --player=spotify stop";
    "XF86AudioPrev".dsp.exec_cmd = "${player-control} --player=spotify previous";
    "XF86AudioNext".dsp.exec_cmd = "${player-control} --player=spotify next";

    "XF86MonBrightnessUp".dsp.exec_cmd = "${brightness-control}/bin/brightness-control --inc";
    "XF86MonBrightnessDown".dsp.exec_cmd = "${brightness-control}/bin/brightness-control --dec";

    "XF86HomePage".dsp.exec_cmd = "${brightness-control}/bin/brightness-control --inc";
    "XF86Mail".dsp.exec_cmd = "${brightness-control}/bin/brightness-control --dec";
  };
}
