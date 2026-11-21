{
  pkgs,
  config,
  lib,
  meta,
  ...
}:
let
  c = config.lib.stylix.colors;
  font = config.stylix.fonts.monospace.name;
  rgba =
    base: alpha: "rgba(${c."${base}-rgb-r"}, ${c."${base}-rgb-g"}, ${c."${base}-rgb-b"}, ${alpha})";
  icons = "${pkgs.wlogout}/share/wlogout/icons";

  wlogout = "${config.programs.wlogout.package}/bin/wlogout";
  pkill = "${pkgs.procps}/bin/pkill";
  toggle-wlogout = "${pkill} -x wlogout || ${wlogout}";
in
{
  config = lib.mkMerge [
    {
      programs.wlogout = {
        enable = true;

        layout = [
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

        style = ''
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

    (lib.mkIf (meta.desktop == "hyprland") {
      programs.hyprland.settings.binds = {
        "XF86PowerOff".dsp.exec_cmd = toggle-wlogout;
        "Mod+Escape".dsp.exec_cmd = toggle-wlogout;
      };

      # 600 keeps Logout after Lock (mkBefore = 500 in hyprlock.nix) and before the common entries (1000)
      programs.wlogout.layout = lib.mkOrder 600 [
        {
          label = "logout";
          action = "hyprctl dispatch exit";
          text = "Logout";
          keybind = "e";
        }
      ];
    })
  ];
}
