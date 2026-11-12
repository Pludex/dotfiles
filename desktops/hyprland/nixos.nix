{
  pkgs,
  host,
  sPkgs,
  ...
}:
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
    videoDrivers = host.gpus;
  };

  hardware.graphics = {
    enable = true;
    package = sPkgs.mesa;
    package32 = sPkgs.pkgsi686Linux.mesa;
  };

  services.logind.settings.Login.HandlePowerKey = "ignore";
}
