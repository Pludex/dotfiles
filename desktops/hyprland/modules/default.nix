{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;
    systemd.enable = true;
  };

  stylix.targets.hyprland.enable = true;
  imports = [
    ./settings.nix
  ];
}
