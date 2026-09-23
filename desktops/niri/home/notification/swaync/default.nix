{ config, ... }:

let
  cfg = config.services.swaync;
  jsonConfig = builtins.fromJSON (builtins.readFile ./config.json);

  style = builtins.readFile ./style.css;
in
{
  services.swaync = {
    inherit style;
    enable = true;
    settings = jsonConfig;
  };

  xdg.configFile = {
    "swaync/configSchema.json".source = "${cfg.package}/etc/xdg/swaync/configSchema.json";
  };
}
