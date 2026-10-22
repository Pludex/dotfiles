{ lib, config, ... }:
{
  config = lib.mkIf (!config.isContainer) {
    gtk = {
      enable = true;
    };

    home.file.".gtkrc-2.0".enable = false;

    stylix.targets.gtk.enable = true;
  };
}
