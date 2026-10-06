{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  include = [ "${./config.jsonc}" ];

  term = "kitty --class waybar-tui -e";

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

  gpuDrivers = osConfig.host-config.gpuDrivers;

  gpuScripts = {
    nvidia = pkgs.writeShellScript "waybar-gpu-nvidia" ''
      /run/current-system/sw/bin/nvidia-smi \
        --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1 | tr -d ' '
    '';

    amd = pkgs.writeShellScript "waybar-gpu-amd" ''
      for dev in /sys/class/drm/card*/device; do
        if [ "$(cat "$dev/vendor" 2>/dev/null)" = 0x1002 ] && [ -r "$dev/gpu_busy_percent" ]; then
          cat "$dev/gpu_busy_percent"
          exit 0
        fi
      done
      echo 0
    '';

    # Needs CAP_PERFMON, see the note below
    intel = pkgs.writeShellScript "waybar-gpu-intel" ''
      top=/run/wrappers/bin/intel_gpu_top
      [ -x "$top" ] || top=${lib.getExe' pkgs.intel-gpu-tools "intel_gpu_top"}
      "$top" -J -s 1000 -n 2 2>/dev/null \
        | ${lib.getExe pkgs.jq} -rs 'flatten | last | [(.engines // {})[].busy] | (max // 0) | round'
    '';
  };

  gpuTag = name: lib.optionalString (lib.length gpuDrivers > 1) "${lib.toUpper name} ";

  gpuModules = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "custom/gpu-${name}" {
        exec = "${gpuScripts.${name}}";
        interval = 5;
        format = "󰾲  ${gpuTag name}{}%";
        tooltip = false;
        on-click = "${term} nvtop";
      }
    ) gpuDrivers
  );

  gpuNames = map (name: "custom/gpu-${name}") gpuDrivers;

  commonModules = {
    cpu.on-click = "${term} btop";
    memory.on-click = "${term} btop";
    disk.on-click = "${term} ncdu /";

    pulseaudio = {
      on-click = "${term} pulsemixer";
      on-click-right = "pavucontrol";
      on-click-middle = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
    };

    mpris = {
      on-click = "playerctl -p spotify play-pause";
      on-click-right = "playerctl -p spotify next";
      on-click-middle = "playerctl -p spotify previous";
    };

    "custom/spotify".on-click = "playerctl -p spotify status >/dev/null 2>&1 || spotify";
  };

  barBase = {
    inherit include;
    height = 28;
    spacing = 6;
    margin-left = 8;
    margin-right = 8;
  };

  island = modules: {
    orientation = "horizontal";
    inherit modules;
  };
in
{
  home.packages = with pkgs; [
    myPkgs.waycal
    playerctl
    sway-audio-idle-inhibit
    btop
    ncdu
    pulsemixer
    nvtopPackages.full
  ];

  # scale waycal
  stylix.targets.gtk.extraCss =
    let
      c = config.lib.stylix.colors;
    in
    ''
      window.waycal {
        background: alpha(#${c.base00}, 0.92);
        border: 1px solid alpha(#${c.base0D}, 0.4);
        border-radius: 16px;
        font-size: 1.6rem;
      }

      window.waycal calendar {
        background: transparent;
        padding: 12px;
      }

      window.waycal calendar > header {
        margin-bottom: 8px;
      }

      window.waycal button {
        border-radius: 10px;
        padding: 6px 12px;
        background: transparent;
      }

      window.waycal button:hover {
        background: alpha(#${c.base0D}, 0.2);
      }

      window.waycal label.day-number {
        border-radius: 10px;
        padding: 6px 12px;
      }

      window.waycal label.day-number.today {
        background: #${c.base0D};
        color: #${c.base00};
      }

      window.waycal label.other-month {
        color: #${c.base03};
      }

      window.waycal label.week-number {
        color: #${c.base04};
      }
    '';

  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    style = ''
      @import url("${./style.css}");
      * { font-family: "${config.stylix.fonts.monospace.name}"; }
    '';
    settings = [
      (
        barBase
        // commonModules
        // gpuModules
        // {
          position = "top";
          margin-top = 4;

          network = {
            format = "󰁝 {bandwidthUpBits}  󰁅 {bandwidthDownBits}";
            on-click = "${term} nmtui";
          };

          "group/wm" = island ([ wm.workspaces ] ++ lib.optional (wm.layout != null) wm.layout);
          "group/datetime" = island [
            "clock#2"
            "clock#4"
          ];
          "group/stats" = island (
            [
              "network"
              "memory"
              "cpu"
            ]
            ++ gpuNames
            ++ [
              "disk"
              "battery"
            ]
          );

          modules-left = [
            "group/wm"
            "custom/sunix"
          ];
          modules-center = [ "group/datetime" ];
          modules-right = [
            "tray"
            "group/stats"
          ];
        }
      )
      (
        barBase
        // commonModules
        // {
          position = "bottom";
          height = 30;
          margin-bottom = 4;

          network = {
            format = "{ifname}";
            "format-wifi" = "󰖩 {ipaddr}/{cidr}";
            "format-ethernet" = "󰈀 {ifname}";
            "format-disconnected" = "󰖪 Offline";
            "tooltip-format" = "{ifname} via {gwaddr}";
            "tooltip-format-wifi" = "{essid} ({signalStrength}%)";
            "tooltip-format-ethernet" = "{ipaddr}/{cidr}";
            "tooltip-format-disconnected" = "Disconnected";
            "max-length" = 50;
            on-click = "${term} wifitui";
          };

          "group/media" = island [
            "custom/spotify"
            "mpris"
          ];
          "group/controls" = island [
            "network"
            "pulseaudio"
            "custom/audio_idle_inhibitor"
            "custom/notification"
          ];

          modules-left = [ "group/media" ];
          modules-center = [ wm.window ];
          modules-right = lib.optional (wm.mode != null) wm.mode ++ [ "group/controls" ];

          ${wm.mode} = {
            format = "{}";
            always-on = true;
          };

          ${wm.window} = {
            "format" = "{title}";
            "rewrite" = {
              "^.*Github.*" = "  Github";
              "~/(.*)" = "   [~/$1]";
              "nvim (.*)" = "   [$1]";
              "(.*)fish" = " 󰈺 [~/$1]";
            };
            "icon" = true;
            "max-length" = 100;
            "separate-outputs" = true;
          };
        }
      )
    ];
    systemd.enable = true;
  };

  stylix.targets.waybar = {
    enable = true;
    colors.enable = true;
  };
}
