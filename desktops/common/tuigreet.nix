{
  pkgs,
  meta,
  ...
}:
let
  inherit (meta) desktop;
  cmd =
    if (desktop == "hyprland") then
      "start-hyprland"
    else
      throw "modules.nixos.services.tuigreet: unable to determine the cmd for desktop '${desktop}'";
in
{
  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        user = "greeter";
        command =
          "${pkgs.tuigreet}/bin/tuigreet"
          + " --time"
          + " --remember"
          + " --asterisks"
          + " --sessions /run/current-system/sw/share/wayland-sessions:/etc/xdg/wayland-sessions"
          + " --cmd ${cmd}";
      };
    };
  };

  services.logind.settings.Login.HandlePowerKey = "ignore";
}
