let
  nixosModule =
    { config, ... }:
    {
      programs.mango.enable = true;
      services.xserver = {
        enable = true;
        videoDrivers = config.host-config.gpuDrivers;
      };
    };
in
{
  desktops.mango = {
    modules.home.extra = [
      ./core
      ./modules
      ./control.nix
      ./nixos.nix
      ./wallpaper.nix
    ];

    modules.nixos.extra = [
      nixosModule
    ];

    tools = {
      launcher = "walker";
      lock-screen = "hyprlock";
      status-bar = "waybar";
      clipboard = "clipse";
      display-manager = "tuigreet";
      # logout = "wlogout";
      notification = "swaync";
    };
  };
}
