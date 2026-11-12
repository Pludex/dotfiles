{
  base,
  lib,
  osConfig ? null,
  config,
  meta,
  inputs,
  ...
}:
let
  inherit (base) libx;
  inherit (config) isContainer;

  app = libx.tryOr (base.app meta.name) null;

  env =
    if isContainer then
      {
        identity = {
          inherit (app) username;
          home = app.home;
        };
        secrets = {
          file = app.age.defaultFile;
          key = app.age.privateKeyPath;
        };
        registry = {
          nixpkgs = "file:///workspaces/dotfiles-ref";
        };
      }
    else
      {
        identity = {
          inherit (base) username;
          home = base.abs.home;
        };
        secrets = {
          file = base.age.defaultFile;
          key = base.age.privateKeyPath;
        };
        registry = {
          nixpkgs = "file:///workspaces/dotfiles";
        };
      };

  forceIfContainer = if isContainer then lib.mkForce else lib.id;
in
{
  imports = [
    ./input-method
    ./programs
    ./services
    ./style.nix

    inputs.sops-nix.homeManagerModules.sops
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

  config = lib.mkMerge [
    {
      home.stateVersion = "26.05";
      isContainer = if osConfig == null then lib.mkDefault false else osConfig.isContainer;
    }

    {
      programs.man.generateCaches = false;
      systemd.user.startServices = "sd-switch";
      home.sessionVariables = base.tools.envvars;
    }

    {
      home.username = forceIfContainer env.identity.username;
      home.homeDirectory = forceIfContainer env.identity.home;
    }

    {
      sops = {
        defaultSopsFile = env.secrets.file;
        age.keyFile = env.secrets.key;
      };
    }

    {
      nix.registry.nixpkgs.to = {
        type = "git";
        url = env.registry.nixpkgs;
      };
    }

    (lib.mkIf (!isContainer) {
      nix.registry.dotfiles.to = {
        type = "git";
        url = "file:///workspaces/dotfiles";
      };
    })

    (lib.mkIf isContainer { inherit app; })
  ];
}
