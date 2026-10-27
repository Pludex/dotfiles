{
  base,
  lib,
  osConfig ? null,
  config,
  meta,
  ...
}:
let
  inherit (base) libx;
  app = libx.tryOr (base.app meta.name) null;
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
      home.username = lib.mkForce app.username;
      home.homeDirectory = lib.mkForce app.home;

      inherit app;
    })
  ];

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    app = lib.mkOption {
      type = lib.types.raw;
      default = app;
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
