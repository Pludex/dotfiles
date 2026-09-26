{
  config.wayland.windowManager.river = {
    enable = true;
    xwayland.enable = true;
  };

  config.stylix.targets.river.enable = true;

  imports = [ ./settings.nix ];
}
