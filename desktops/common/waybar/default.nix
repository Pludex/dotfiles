{
  pkgs,
  lib,
  config,
  ...
}:

let
  include = [ "${./config.jsonc}" ];

  # Module names per desktop. Supporting a new WM only needs a new entry here;
  # `layout = null` means the WM has no waybar layout module.
  desktops = {
    mango = {
      workspaces = "mango/workspaces";
      layout = "mango/layout";
      window = "mango/window";
      mode = null;
    };
    hyprland = {
      workspaces = "hyprland/workspaces";
      layout = null;
      window = "hyprland/window";
      mode = "hyprland/submap";
    };
    niri = {
      workspaces = "niri/workspaces";
      layout = null;
      window = "niri/window";
      mode = null;
    };
  };

  wm =
    desktops.${config.desktop}
      or (throw "waybar: unsupported desktop \"${config.desktop}\", expected one of: ${lib.concatStringsSep ", " (lib.attrNames desktops)}");

  sep = [
    "custom/right-arrow-dark"
    "custom/right-arrow-light"
  ];

  sepLeft = [
    "custom/left-arrow-light"
    "custom/left-arrow-dark"
  ];
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
        modules-left =
          sep
          ++ [ wm.workspaces ]
          ++ lib.optionals (wm.layout != null) (sep ++ [ wm.layout ])
          ++ sep
          ++ [
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
          wm.window
          "custom/right-arrow-end"
        ];

        modules-right =
          [
            "custom/left-arrow-end"
            "network"
          ]
          ++ sepLeft
          ++ [ "pulseaudio" ]
          ++ sepLeft
          ++ [ "custom/audio_idle_inhibitor" ]
          ++ sepLeft
          ++ [ "custom/notification" ]
          ++ sepLeft
          ++ lib.optionals (wm.mode != null) ([ wm.mode ] ++ sepLeft);

        ${wm.mode} = {
          format = "{}";
          always-on = true;
        };

        ${wm.window} = {
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
