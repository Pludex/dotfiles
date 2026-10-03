{ pkgs, config, ... }:
let
  volume-control = pkgs.myPkgs.volume-control;
  brightness-control = pkgs.myPkgs.brightness-control;
  player-control = "${pkgs.playerctl}/bin/playerctl";
  wlogout = "${config.programs.wlogout.package}/bin/wlogout";
  hyprlock = "${config.programs.hyprlock.package}/bin/hyprlock";
  pkill = "${pkgs.procps}/bin/pkill";
  toggle-wlogout = "${pkill} -x wlogout || ${wlogout}";

  # Close wlogout first, otherwise it stays open behind the lock screen
  lock = "${pkill} -x wlogout; sleep 0.3; ${hyprlock}";

  c = config.lib.stylix.colors;
  font = config.stylix.fonts.monospace.name;
  rgba =
    base: alpha: "rgba(${c."${base}-rgb-r"}, ${c."${base}-rgb-g"}, ${c."${base}-rgb-b"}, ${alpha})";

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

    "XF86AudioPlay" = locked "${player-control} --player=spotify play-pause";
    "XF86AudioStop" = locked "${player-control} --player=spotify stop";
    "XF86AudioPrev" = locked "${player-control} --player=spotify previous";
    "XF86AudioNext" = locked "${player-control} --player=spotify next";

    "XF86MonBrightnessUp" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86MonBrightnessDown" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86HomePage" = repeat "${brightness-control}/bin/brightness-control --inc";
    "XF86Mail" = repeat "${brightness-control}/bin/brightness-control --dec";

    "XF86PowerOff".dsp.exec_cmd = toggle-wlogout;
    "Mod+Escape".dsp.exec_cmd = toggle-wlogout;
  };

  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        action = lock;
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
    ];

    style =
      let
        icons = "${pkgs.wlogout}/share/wlogout/icons";
      in
      ''
        * {
          background-image: none;
          font-family: "${font}";
          font-size: 16px;
        }

        window {
          background-color: ${rgba "base00" "0.6"};
        }

        button {
          color: #${c.base05};
          background-color: ${rgba "base01" "0.7"};
          border: 2px solid transparent;
          border-radius: 16px;
          margin: 10px;
          background-repeat: no-repeat;
          background-position: center;
          background-size: 25%;
        }

        button:focus,
        button:hover {
          background-color: ${rgba "base02" "0.9"};
          border-color: #${c.base0D};
          outline-style: none;
        }

        #lock      { background-image: url("${icons}/lock.png"); }
        #logout    { background-image: url("${icons}/logout.png"); }
        #suspend   { background-image: url("${icons}/suspend.png"); }
        #hibernate { background-image: url("${icons}/hibernate.png"); }
        #reboot    { background-image: url("${icons}/reboot.png"); }
        #shutdown  { background-image: url("${icons}/shutdown.png"); }
      '';
  };
}
