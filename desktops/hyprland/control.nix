{
  pkgs,
  base,
  ...
}:
let
  volume-control = pkgs.myPkgs.volume-control;
  brightness-control = pkgs.myPkgs.brightness-control;
  player-control = "${pkgs.playerctl}/bin/playerctl";
  inherit (base.players) music;

  locked = cmd: {
    dsp.exec_cmd = cmd;
    flags.locked = true;
  };

  repeat = cmd: {
    dsp.exec_cmd = cmd;
    flags = {
      repeating = true;
      locked = true;
    };
  };
in
{
  programs.hyprland.settings.binds = {
    "XF86AudioRaiseVolume" = repeat "${volume-control}/bin/volume-control --inc";
    "XF86AudioLowerVolume" = repeat "${volume-control}/bin/volume-control --dec";
    "XF86AudioMute" = locked "${volume-control}/bin/volume-control --toggle";
    "XF86AudioMicMute" = locked "${volume-control}/bin/volume-control --toggle-mic";

    "Mod+XF86AudioRaiseVolume" = repeat "${brightness-control}/bin/brightness-control --inc";
    "Mod+XF86AudioLowerVolume" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86AudioPlay" = locked "${player-control} --player=${music} play-pause";
    "XF86AudioStop" = locked "${player-control} --player=${music} stop";
    "XF86AudioPrev" = locked "${player-control} --player=${music} previous";
    "XF86AudioNext" = locked "${player-control} --player=${music} next";

    "XF86MonBrightnessUp" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86MonBrightnessDown" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86HomePage" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86Mail" = repeat "${brightness-control}/bin/brightness-control --dec";
  };
}
