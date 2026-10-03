{ config, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  font = config.stylix.fonts.monospace.name;

  rgba = color: alpha: "rgba(${color}${alpha})";

  playerctl = "${pkgs.playerctl}/bin/playerctl";
  curl = "${pkgs.curl}/bin/curl";

  label =
    extra:
    {
      monitor = "";
      font_family = font;
      halign = "center";
      valign = "center";
    }
    // extra;
in
{
  stylix.targets.hyprlock.enable = false;

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        grace = 0;
      };

      animations = {
        enabled = true;
        bezier = "ease, 0.25, 0.1, 0.25, 1";
        animation = [
          "fadeIn, 1, 4, ease"
          "fadeOut, 1, 4, ease"
          "inputFieldDots, 1, 2, ease"
        ];
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 1;
          blur_size = 3;
          brightness = 0.9;
          vibrancy = 0.1;
        }
      ];

      image = [
        {
          monitor = "";
          path = "${config.home.homeDirectory}/.face";
          size = 100;
          rounding = -1;
          border_size = 2;
          border_color = rgba c.base0D "cc";
          position = "0, 300";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "300, 50";
          outline_thickness = 1;
          dots_size = 0.25;
          dots_spacing = 0.3;
          dots_center = true;
          fade_on_empty = true;
          rounding = 12;
          outer_color = rgba c.base0D "66";
          inner_color = rgba c.base00 "26";
          font_color = rgba c.base05 "ff";
          check_color = rgba c.base0A "ff";
          fail_color = rgba c.base08 "ff";
          font_family = font;
          placeholder_text = "<i>Password...</i>";
          fail_text = "<i>$FAIL ($ATTEMPTS)</i>";
          position = "0, -120";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        # Clock
        (label {
          text = "$TIME";
          font_size = 96;
          color = rgba c.base05 "e6";
          position = "0, 160";
        })
        # Date
        (label {
          text = ''cmd[update:60000] date +"%A, %d %B %Y"'';
          font_size = 22;
          color = rgba c.base04 "ff";
          position = "0, 70";
        })
        # Greeting
        (label {
          text = "Hi, $USER";
          font_size = 18;
          color = rgba c.base0D "ff";
          position = "0, 0";
        })
        # Now playing
        (label {
          text = "cmd[update:2000] ${playerctl} metadata --format '{{artist}} - {{title}}' 2>/dev/null";
          font_size = 16;
          color = rgba c.base05 "cc";
          position = "0, 60";
          valign = "bottom";
        })
        # Weather
        (label {
          text = "cmd[update:600000] ${curl} -s 'wttr.in/?format=%c+%t' ";
          font_size = 18;
          color = rgba c.base05 "cc";
          position = "30, -30";
          halign = "left";
          valign = "top";
        })
        # Battery
        (label {
          text = ''cmd[update:30000] echo "BAT $(cat /sys/class/power_supply/BAT0/capacity)%"'';
          font_size = 18;
          color = rgba c.base05 "cc";
          position = "-30, -30";
          halign = "right";
          valign = "top";
        })
        # Uptime
        (label {
          text = "cmd[update:60000] uptime -p";
          font_size = 14;
          color = rgba c.base04 "ff";
          position = "30, 30";
          halign = "left";
          valign = "bottom";
        })
        # Keyboard layout
        (label {
          text = "$LAYOUT";
          font_size = 14;
          color = rgba c.base04 "ff";
          position = "-30, 30";
          halign = "right";
          valign = "bottom";
        })
      ];
    };
  };
}
