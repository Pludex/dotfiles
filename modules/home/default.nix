{
  base,
  lib,
  config,
  meta,
  inputs,
  ...
}:
let
  inherit (base) libx;

  app = libx.tryOr (base.app meta.name) null;
  hasApp = app != null;

  # Hosts with their own app record (containers) take identity from it
  env =
    if hasApp then
      {
        identity = {
          inherit (app) username home;
        };
        secrets = {
          file = app.age.defaultFile;
          key = app.age.privateKeyPath;
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
      };

  forceIfApp = if hasApp then lib.mkForce else lib.id;
in
{
  imports = [
    ./input-method
    ./programs
    ./services
    ./style.nix

    inputs.sops-nix.homeManagerModules.sops
  ];

  options.app = lib.mkOption {
    type = lib.types.raw;
    default = app;
  };

  config = lib.mkMerge [
    {
      home.stateVersion = "26.05";
      programs.man.generateCaches = false;
      systemd.user.startServices = "sd-switch";
      home.sessionVariables = base.tools.envvars;
    }

    {
      home.username = forceIfApp env.identity.username;
      home.homeDirectory = forceIfApp env.identity.home;
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
        url = "file://${base.abs.dotfiles-ref}";
      };
    }

    (lib.mkIf hasApp { inherit app; })
  ];
}
