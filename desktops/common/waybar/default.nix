{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  term = "kitty --class waybar-tui -e";

  playerctl = lib.getExe pkgs.playerctl;
  jq = lib.getExe pkgs.jq;

  extraPkgs = with pkgs; [
    myPkgs.waycal
    playerctl
    sway-audio-idle-inhibit
    btop
    ncdu
    pulsemixer
    nvtopPackages.full
  ];

  # Waybar with extra tools on its own PATH instead of the user profile
  waybarPkg = pkgs.symlinkJoin {
    name = "waybar-wrapped";
    paths = [ pkgs.waybar ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/waybar --prefix PATH : ${lib.makeBinPath extraPkgs}
    '';
    meta.mainProgram = "waybar";
  };

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

    # Needs CAP_PERFMON
    intel = pkgs.writeShellScript "waybar-gpu-intel" ''
      top=/run/wrappers/bin/intel_gpu_top
      [ -x "$top" ] || top=${lib.getExe' pkgs.intel-gpu-tools "intel_gpu_top"}
      "$top" -J -s 1000 -n 2 2>/dev/null \
        | ${jq} -rs 'flatten | last | [(.engines // {})[].busy] | (max // 0) | round'
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

  mediaScript = pkgs.writeShellScript "waybar-media" ''
    fmt='{{artist}} - {{title}}'

    render() {
      text="No music"
      class="stopped"
      status=$(${playerctl} -p spotify status 2>/dev/null)
      if [ -n "$status" ]; then
        class=''${status,,}
        text=$(${playerctl} -p spotify metadata --format "$fmt" 2>/dev/null)
      fi

      tooltip=$(${playerctl} -l 2>/dev/null | while read -r p; do
        case $(${playerctl} -p "$p" status 2>/dev/null) in
          Playing) icon="▶" ;;
          Paused) icon="⏸" ;;
          *) icon="⏹" ;;
        esac
        name=''${p%%.instance*}
        info=$(${playerctl} -p "$p" metadata --format "$fmt" 2>/dev/null)
        printf '%s  %s: %s\n' "$icon" "$name" "$info"
      done)
      [ -n "$tooltip" ] || tooltip="No players"

      ${jq} -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
        '{text: $text, tooltip: $tooltip, class: $class}'
    }

    render
    while true; do
      ${playerctl} -p spotify --follow metadata \
        --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null \
        | while read -r _; do render; done
      render
      sleep 2
    done
  '';

  mediaPick = pkgs.writeShellScript "waybar-media-pick" ''
    choice=$(${playerctl} -l | ${lib.getExe pkgs.walker} --dmenu) || exit 0
    [ -n "$choice" ] || exit 0
    ${playerctl} -p "$choice" play-pause
  '';

  commonModules = {
    "mango/workspaces" = {
      disable-scroll = false;
      all-outputs = false;
      format = "{icon}";
      format-icons = {
        "1" = " ";
        "2" = "󰈙 ";
        "4" = " ";
        "8" = " ";
        "16" = "󰗔 ";
        default = "";
      };
    };

    "clock#1" = {
      format = "{:%a}";
      tooltip = false;
    };

    "clock#2" = {
      format = "󰥔  {:%H:%M}";
      tooltip-format = "{:%A}";
    };

    "clock#3" = {
      format = "{:%b %d}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        weeks-pos = "right";
        on-scroll = 1;
        format = {
          months = "<span color='#ffead3'><b>{}</b></span>";
          days = "<span color='#ecc6d9'><b>{}</b></span>";
          weeks = "<span color='#99ffdd'><b>W{}</b></span>";
          weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          today = "<span color='#ff6699'><b><u>{}</u></b></span>";
        };
      };
      actions = {
        on-click-right = "mode";
        on-click-forward = "tz_up";
        on-click-backward = "tz_down";
        on-scroll-up = "shift_up";
        on-scroll-down = "shift_down";
      };
    };

    "clock#4" = {
      format = "󰃭  {:%a, %d %b}";
      tooltip = false;
      on-click = "pgrep -io 'waycal' | xargs kill || waycal";
    };

    pulseaudio = {
      format = "{icon}{volume}%";
      format-bluetooth = "󰂰 {volume}%";
      format-muted = "  muted";
      format-icons = {
        headphones = "󰋋";
        default = [
          " "
          " "
          " "
        ];
      };
      scroll-step = 5;
      on-click = "${term} pulsemixer";
      on-click-right = "pavucontrol";
      on-click-middle = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
    };

    memory = {
      interval = 5;
      format = "󰍛  {}%";
      on-click = "${term} btop";
    };

    cpu = {
      interval = 5;
      format = "󰻠  {usage}%";
      tooltip = false;
      on-click = "${term} btop";
    };

    temperature = {
      format = " {temperatureC}°C";
      tooltip = false;
    };

    battery = {
      states = {
        good = 95;
        warning = 30;
        critical = 15;
      };
      format = "{icon}  {capacity}%";
      format-charging = "󰂄  {capacity}%";
      format-plugged = "󰚥  {capacity}%";
      format-icons = [
        "󰂎"
        "󰁼"
        "󰁾"
        "󰂀"
        "󰁹"
      ];
    };

    disk = {
      interval = 5;
      format = "󰋊  {percentage_used}%";
      path = "/";
      on-click = "${term} ncdu /";
    };

    tray = {
      icon-size = 14;
      show-passive-items = true;
      spacing = 6;
    };

    "custom/media" = {
      exec = "${mediaScript}";
      return-type = "json";
      # interval = 2;
      escape = true;
      on-click = "${playerctl} -p spotify play-pause";
      on-click-right = "${mediaPick}";
    };

    "custom/spotify" = {
      format = "󰓇 ";
      tooltip = false;
    };

    "group/group-power" = {
      orientation = "inherit";
      drawer = {
        transition-duration = 500;
        children-class = "not-power";
        transition-left-to-right = true;
      };
      modules = [
        "custom/power"
        "custom/quit"
        "custom/lock"
        "custom/reboot"
      ];
    };

    "custom/quit" = {
      format = "󰗼 ";
      tooltip = true;
      tooltip-format = "Exit Session";
      on-click = "hyprctl dispatch exit";
    };

    "custom/lock" = {
      format = "󰍁 ";
      tooltip = true;
      tooltip-format = "Lock";
      on-click = "hyprlock";
    };

    "custom/reboot" = {
      format = "󰜉 ";
      tooltip = true;
      tooltip-format = "Reboot";
      on-click = "reboot";
    };

    "custom/power" = {
      format = "󰐥 ";
      tooltip = true;
      tooltip-format = "Power Off";
      on-click = "poweroff";
    };

    "custom/audio_idle_inhibitor" = {
      format = "{icon}";
      tooltip = false;
      exec = "sway-audio-idle-inhibit --ignore-source-outputs 'cava,PulseAudio Volume Control' --dry-print-both-waybar";
      exec-if = "which sway-audio-idle-inhibit";
      return-type = "json";
      format-icons = {
        output = "󰓃";
        input = "󰍬";
        output-input = "󰓃 󰍬";
        none = "󰓄";
      };
    };

    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰅶";
        deactivated = "󰾪";
      };
    };

    "custom/notification" = {
      tooltip = false;
      format = " {icon} ";
      format-icons = {
        notification = "󰂚<span foreground='red'><sup></sup></span>";
        none = "󰂜";
        dnd-notification = "󰂛<span foreground='red'><sup></sup></span>";
        dnd-none = "󰂛";
        inhibited-notification = "󰂚<span foreground='red'><sup></sup></span>";
        inhibited-none = "󰂜";
        dnd-inhibited-notification = "󰂛<span foreground='red'><sup></sup></span>";
        dnd-inhibited-none = "󰂛";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };

    "custom/sunix" = {
      format = " SUNix";
      on-click = "pgrep -io 'sunix' | xargs kill || sunix";
      tooltip-format = "Software Updates for Nix";
      tooltip = false;
    };

    "mango/layout" = {
      format = " {symbol} ";
      format-T = " 󰕴 Tile ";
      format-S = "  Scroller ";
      format-M = " 󰊓 Monocle ";
      format-G = " 󰝘 Grid ";
      format-K = "  Deck ";
      format-CT = "  Center Tile ";
      format-RT = "  Right Tile ";
      format-VT = "  Vertical Tile ";
      format-VS = "  Vertical Scroller ";
      format-VG = "  Vertical Grid ";
      format-VK = "  Vertical Deck ";
      format-DW = "  Dwindle ";
      format-F = "  Fair ";
      format-VF = "  Vertical Fair ";
      tooltip = false;
      expand = false;
    };

    "hyprland/submap" = {
      format = " {icon} {submap} ";
      max-length = 8;
      tooltip = false;
      icons = {
        resize = "";
      };
    };
  };

  barBase = {
    layer = "top";
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
    package = waybarPkg;
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
            # "custom/sunix"
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
            "custom/media"
          ];

          "group/controls" = island [
            "network"
            "pulseaudio"
            "custom/audio_idle_inhibitor"
            "custom/notification"
          ];

          modules-left = [
            "group/media"
          ];
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
