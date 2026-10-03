{ pkgs, config, ... }:
let
  volume-control = pkgs.myPkgs.volume-control;
  brightness-control = pkgs.myPkgs.brightness-control;
  player-control = "${pkgs.playerctl}/bin/playerctl";
  wlogout = "${config.programs.wlogout.package}/bin/wlogout";
  toggle-wlogout = "pkill wlogout || ${wlogout}";

  repeat = cmd: {
    dsp.exec_cmd = cmd;
    flags.repeating = true;
  };
in
{
  programs.hyprland.settings.binds = {
    "XF86AudioRaiseVolume" = repeat "${volume-control}/bin/volume-control --inc";
    "XF86AudioLowerVolume" = repeat "${volume-control}/bin/volume-control --dec";
    "XF86AudioMute".dsp.exec_cmd = "${volume-control}/bin/volume-control --toggle";
    "XF86AudioMicMute".dsp.exec_cmd = "${volume-control}/bin/volume-control --toggle-mic";

    "Mod+XF86AudioRaiseVolume" = repeat "${brightness-control}/bin/brightness-control --inc";
    "Mod+XF86AudioLowerVolume" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86AudioPlay".dsp.exec_cmd = "${player-control} --player=spotify play-pause";
    "XF86AudioStop".dsp.exec_cmd = "${player-control} --player=spotify stop";
    "XF86AudioPrev".dsp.exec_cmd = "${player-control} --player=spotify previous";
    "XF86AudioNext".dsp.exec_cmd = "${player-control} --player=spotify next";

    "XF86MonBrightnessUp" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86MonBrightnessDown" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86HomePage" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86Mail" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86PowerOff".dsp.exec_cmd = toggle-wlogout;
    "Mod+Escape".dsp.exec_cmd = toggle-wlogout;
  };
}
