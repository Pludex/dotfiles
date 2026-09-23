{ pkgs, ... }:
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
          + " --cmd niri-session";
      };
    };
  };

  systemd.user.services.niri.enableDefaultPath = false;
}
