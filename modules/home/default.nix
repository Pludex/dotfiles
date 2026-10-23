{
  base,
  lib,
  osConfig ? null,
  config,
  ...
}:
let
  bot = base.botOf config.name;
in
{
  config = lib.mkMerge [
    {
      home.stateVersion = "26.05";

      isContainer = if (osConfig == null) then lib.mkDefault false else osConfig.isContainer;
      programs.man.generateCaches = false;
      home.sessionVariables = base.tools.envvars;
    }

    (lib.mkIf (!config.isContainer) {
      home.username = base.username;
      home.homeDirectory = base.abs.home;
    })

    (lib.mkIf (config.isContainer) {
      home.username = lib.mkForce bot.username;
      home.homeDirectory = lib.mkForce bot.abs.home;

      inherit bot;
    })
  ];

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    bot = lib.mkOption {
      type = lib.types.raw;
      default = null;
    };
  };

  imports = [
    ./input-method
    ./programs
    ./services
    ./gtk.nix
    ./nix-config.nix
    ./sops.nix
    ./style.nix
    ./systemd.nix
    ./xdg.nix
  ];
}
