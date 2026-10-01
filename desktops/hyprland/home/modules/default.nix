{ inputs, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;
    systemd.enable = false;
  };

  stylix.targets.hyprland.enable = true;
  imports = [
    ./settings.nix
  ];
}
