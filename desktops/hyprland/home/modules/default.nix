{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = false; # for test
  };

  stylix.targets.hyprland.enable = true;
  imports = [
    ./settings.nix
  ];
}
