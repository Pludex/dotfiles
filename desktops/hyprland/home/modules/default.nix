{ inputs, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.system}.default;
    xwayland.enable = true;
    systemd.enable = false;
  };

  stylix.targets.hyprland.enable = true;
  imports = [
    ./settings.nix
  ];
}
