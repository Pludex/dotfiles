{ lib, meta, ... }:
{
  services.kanata = lib.mkIf meta.isInteractive {
    enable = true;
    keyboards = {
      default = {
        devices = [ ];
        extraDefCfg = "concurrent-tap-hold yes";
        config = builtins.readFile ./kanata.kbd;
      };
    };
  };
}
