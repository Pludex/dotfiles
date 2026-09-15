{ lib, config, ... }:
let
  S = config.programs.mango.superKey;
in
{
  options.programs = {
    mango = {
      superKey = lib.mkOption {
        type = lib.types.str;
        description = "SUPER KEY MAP";
      };
    };
  };

  config = {
    programs.mango.superKey = "ALT"; # nested in niri

    wayland.windowManager.mango.settings.bind = [
      "${S},Q,killclient"
      "${S}+SHIFT,Q,quit"
    ];
  };
}
