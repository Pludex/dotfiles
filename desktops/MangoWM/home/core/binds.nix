{ lib, config, ... }:
{
  config.programs.mango.settings = {
    superKey = "CTRL"; # in niri

    bind = [
      "SUPER+SHIFT,Q,quit"
    ];
  };

  options.programs.mango.settings = {
    superKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPER";
    };

    bind = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = {
    wayland.windowManager.mango.settings.bind = map (
      b: lib.replaceStrings [ "SUPER" ] [ config.programs.mango.settings.superKey ] b
    ) config.programs.mango.settings.bind;
  };
}
