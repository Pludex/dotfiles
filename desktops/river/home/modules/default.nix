{ lib, config, ... }:
{
  config.wayland.windowManager.river = {
    enable = true;
    xwayland.enable = true;
  };

  config.stylix.targets.river.enable = true;

  config.wayland.windowManager.river.extraConfig = ''
    ${lib.getExe config.programs.river._Results.keyMaps}
  '';

  imports = [
    ./keymaps.nix
  ];
}
