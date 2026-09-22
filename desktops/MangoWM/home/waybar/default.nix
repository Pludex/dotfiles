{ pkgs, ... }:

let
  include = [ "${./config.jsonc}" ];
in
{
  home.packages = with pkgs; [
    myPkgs.waycal
    playerctl
    sway-audio-idle-inhibit
  ];

  # scale waycal
  stylix.targets.gtk.extraCss = ''
    window.waycal, .waycal {
        font-size: 2.0rem;
    }

    window.waycal button, window.waycal label {
        padding: 6px 12px;
    }
  '';

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    style = ''
      @import url("${./style.css}");
    '';
    settings = [
      {
        inherit include;
        position = "top";
        network = {
          "format" = " {bandwidthUpBits}  {bandwidthDownBits}";
        };
        modules-left = [
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "mango/workspaces"
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "mango/layout"
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "custom/sunix"
          "custom/right-arrow-end"
        ];

        modules-center = [
          "custom/left-arrow-end"
          "clock#2"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "tray"
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "clock#4"
          "custom/right-arrow-end"
        ];
        modules-right = [
          "custom/left-arrow-end"
          "network"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "memory"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "cpu"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          #"custom/gpu-usage"
          #"custom/left-arrow-light"
          #"custom/left-arrow-dark"
          # "temperature"
          # "custom/left-arrow-light"
          # "custom/left-arrow-dark"
          "disk"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "battery"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
        ];
      }
      {
        inherit include;
        position = "bottom";

        network = {
          format = "{ifname}";
          "format-wifi" = "{ipaddr}/{cidr} ";
          "format-ethernet" = "{ifname} ";
          "format-disconnected" = " ";
          "tooltip-format" = "{ifname} via {gwaddr} 󰊗";
          "tooltip-format-wifi" = "{essid} ({signalStrength}%) ";
          "tooltip-format-ethernet" = "{ipaddr}/{cidr} 󰊗";
          "tooltip-format-disconnected" = "Disconnected 󰌙";
          "max-length" = 50;
        };

        modules-left = [
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "custom/spotify"
          "custom/mpris"
          "custom/right-arrow-end"
        ];

        modules-center = [
          "custom/left-arrow-end"
          "mango/window"
          "custom/right-arrow-end"
        ];

        modules-right = [
          "custom/left-arrow-end"
          "network"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "pulseaudio"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "custom/audio_idle_inhibitor"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "custom/notification"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "group/group-power"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
        ];

        "mango/window" = {
          "format" = "{title}";
          "rewrite" = {
            "^.*Github.*" = "  Github";
            "~/(.*)" = "   [~/$1]";
            "nvim (.*)" = "   [$1]";
            "(.*)fish" = " 󰈺 [~/$1]";
          };
          "icon" = true;
          "max-length" = 50;
          "separate-outputs" = true;
        };
      }
    ];
    systemd.enable = true;
  };
  stylix.targets.waybar = {
    enable = true;
    colors.enable = false;
  };
}
