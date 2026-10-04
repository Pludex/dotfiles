{ config, pkgs, ... }:
let
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  hyprlock = "${config.programs.hyprlock.package}/bin/hyprlock";
  wlogout = "${config.programs.wlogout.package}/bin/wlogout";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  bluetoothctl = "${pkgs.bluez}/bin/bluetoothctl";
  rfkill = "${pkgs.util-linux}/bin/rfkill";
  swaync-client = "${config.services.swaync.package}/bin/swaync-client";

  c = config.lib.stylix.colors;
  font = config.stylix.fonts.monospace.name;
in
{
  # Custom CSS below replaces the stylix-generated one
  stylix.targets.swaync.enable = false;

  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "bottom";
      layer = "overlay";
      control-center-layer = "top";
      cssPriority = "user";

      control-center-width = 420;
      control-center-height = 760;
      control-center-margin-top = 0;
      control-center-margin-right = 10;
      control-center-margin-bottom = 10;
      control-center-margin-left = 0;

      notification-window-width = 400;
      notification-icon-size = 48;
      notification-body-image-height = 120;
      notification-body-image-width = 200;
      notification-inline-replies = true;

      timeout = 8;
      timeout-low = 5;
      timeout-critical = 0;
      transition-time = 200;
      fit-to-screen = false;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;

      widgets = [
        "title"
        "dnd"
        "menubar#power"
        "buttons-grid"
        "volume"
        "backlight"
        "mpris"
        "notifications"
      ];

      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };

        dnd.text = "Do Not Disturb";

        "menubar#power" = {
          "menu#power" = {
            label = "󰐥  Power";
            position = "right";
            actions = [
              {
                label = "󰌾  Lock";
                command = hyprlock;
              }
              {
                label = "󰤄  Suspend";
                command = "systemctl suspend";
              }
              {
                label = "󰜉  Reboot";
                command = "systemctl reboot";
              }
              {
                label = "󰐥  Shutdown";
                command = "systemctl poweroff";
              }
            ];
          };
        };

        buttons-grid = {
          buttons-per-row = 3;
          actions = [
            {
              label = "󰖩";
              type = "toggle";
              active = true;
              command = "sh -c '[[ $SWAYNC_TOGGLE_STATE == true ]] && ${nmcli} radio wifi on || ${nmcli} radio wifi off' ";
              update-command = ''sh -c '[[ $(${nmcli} radio wifi) == "enabled" ]] && echo true || echo false' '';
            }
            {
              label = "󰂯";
              type = "toggle";
              active = true;
              command = "sh -c '[[ $SWAYNC_TOGGLE_STATE == true ]] && ${rfkill} unblock bluetooth || ${rfkill} block bluetooth' ";
              update-command = ''sh -c '${bluetoothctl} show | grep -q "Powered: yes" && echo true || echo false' '';
            }
            {
              label = "󰍭";
              type = "toggle";
              active = false;
              command = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
              update-command = "sh -c '${wpctl} get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo true || echo false' ";
            }
            {
              label = "󰹑";
              command = "sh -c '${swaync-client} -cp; sleep 0.4; ${hyprshot} -m region --clipboard-only' ";
            }
            {
              label = "󰌾";
              command = "sh -c '${swaync-client} -cp; ${hyprlock}' ";
            }
            {
              label = "󰍃";
              command = "sh -c '${swaync-client} -cp; ${wlogout}' ";
            }
          ];
        };

        volume = {
          label = "󰕾";
          show-per-app = true;
          show-per-app-icon = true;
          show-per-app-label = false;
        };

        backlight = {
          label = "󰃟";
          subsystem = "backlight";
          device = "intel_backlight";
        };

        mpris = {
          image-size = 96;
          image-radius = 12;
        };
      };
    };

    style = ''
      @define-color base00 #${c.base00};
      @define-color base01 #${c.base01};
      @define-color base02 #${c.base02};
      @define-color base03 #${c.base03};
      @define-color base04 #${c.base04};
      @define-color base05 #${c.base05};
      @define-color base08 #${c.base08};
      @define-color base0D #${c.base0D};

      * {
        font-family: "${font}";
        font-size: 14px;
      }

      /* Notifications */
      .notification-row {
        outline: none;
      }

      .notification {
        background: alpha(@base00, 0.85);
        border: 1px solid alpha(@base0D, 0.5);
        border-radius: 14px;
        margin: 6px 12px;
        padding: 0;
      }

      .notification.critical {
        border-color: @base08;
      }

      .notification-content {
        background: transparent;
        padding: 10px;
      }

      .summary {
        color: @base05;
        font-weight: bold;
      }

      .body {
        color: @base04;
      }

      .time {
        color: @base03;
      }

      .close-button {
        background: @base01;
        color: @base05;
        border-radius: 99px;
        margin: 6px;
        padding: 2px;
      }

      .close-button:hover {
        background: @base08;
        color: @base00;
      }

      .notification-action > button {
        background: alpha(@base02, 0.8);
        color: @base05;
        border: none;
        border-radius: 10px;
        margin: 4px;
      }

      .notification-action > button:hover {
        background: @base0D;
        color: @base00;
      }

      /* Control center */
      .control-center {
        background: alpha(@base00, 0.85);
        border: 1px solid alpha(@base0D, 0.5);
        border-radius: 18px;
        padding: 8px;
      }

      .control-center-list {
        background: transparent;
      }

      .widget-title {
        margin: 8px;
        color: @base05;
        font-size: 1.3em;
      }

      .widget-title > button {
        background: @base01;
        color: @base05;
        border: none;
        border-radius: 10px;
        padding: 4px 14px;
      }

      .widget-title > button:hover {
        background: @base0D;
        color: @base00;
      }

      .widget-dnd {
        margin: 8px;
        color: @base05;
      }

      .widget-dnd > switch {
        background: @base01;
        border: none;
        border-radius: 99px;
      }

      .widget-dnd > switch:checked {
        background: @base0D;
      }

      .widget-dnd > switch slider {
        background: @base05;
        border-radius: 99px;
      }

      .widget-menubar {
        margin: 0 8px;
      }

      .widget-menubar button {
        background: @base01;
        color: @base05;
        border: none;
        border-radius: 10px;
        padding: 4px 12px;
      }

      .widget-menubar button:hover {
        background: @base0D;
        color: @base00;
      }

      .widget-buttons-grid {
        background: alpha(@base01, 0.6);
        border-radius: 14px;
        margin: 8px;
        padding: 6px;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button {
        background: @base02;
        color: @base05;
        border: none;
        border-radius: 12px;
        margin: 4px;
        min-height: 48px;
        font-size: 18px;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button:hover {
        background: @base03;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button:checked {
        background: @base0D;
        color: @base00;
      }

      .widget-volume,
      .widget-backlight {
        background: alpha(@base01, 0.6);
        color: @base05;
        border-radius: 14px;
        margin: 8px;
        padding: 8px;
      }

      scale trough {
        background: @base02;
        border-radius: 99px;
        min-height: 6px;
      }

      scale highlight {
        background: @base0D;
        border-radius: 99px;
      }

      scale slider {
        background: @base05;
        border: none;
        border-radius: 99px;
        min-height: 14px;
        min-width: 14px;
      }

      .widget-mpris {
        background: alpha(@base01, 0.6);
        border-radius: 14px;
        margin: 8px;
        padding: 8px;
      }

      .widget-mpris-title {
        color: @base05;
        font-weight: bold;
      }

      .widget-mpris-subtitle {
        color: @base04;
      }

      .widget-mpris button {
        background: transparent;
        color: @base05;
        border: none;
      }

      .widget-mpris button:hover {
        color: @base0D;
      }
    '';
  };
}
