let
  nixosModule =
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

      services.xserver = {
        enable = true;
        videoDrivers = host.gpus;
      };

      hardware.graphics = {
        enable = true;
        package = sPkgs.mesa;
        package32 = sPkgs.pkgsi686Linux.mesa;
      };
    };
in
{
  desktops.hyprland = {
    modules = {
      nixos.extra = [
        nixosModule
      ];

      home.extra = [
        ./core
        ./modules
        ./capture.nix
        ./control.nix
        ./session.nix
        ./wallpaper.nix
      ];
    };

    tools.desktop = {
      launcher = "walker";
      lock-screen = "hyprlock";
      status-bar = "waybar";
      clipboard = "clipse";
      display-manager = "tuigreet";
      logout = "wlogout";
      notification = "swaync";
    };
  };
}
