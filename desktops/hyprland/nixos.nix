{ pkgs, config, ... }:
{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;
  };

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
          + " --cmd start-hyprland";
      };
    };
  };

  services.xserver = {
    enable = true;
    videoDrivers = config.host-config.gpuDrivers;
  };
}
