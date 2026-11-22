{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;

  configOptions =
    { lib, ... }:
    {
      options.standalone = lib.mkOption {
        type = lib.types.bool;
        description = "When building home-manager in standalone mode, it evaluates to true, and vice versa";
      };

      options.profile = lib.mkOption {
        type = lib.types.str;
        description = "Profile name currently in use";
      };

      options.desktop = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum (lib.attrNames cfg.desktops));
        description = "Desktop name currently in use, null when headless";
      };

      options.host = lib.mkOption {
        type = lib.types.str;
        description = "Host name currently in use";
      };

      options.role = lib.mkOption {
        type = lib.types.enum (lib.attrNames cfg.roles);
        description = "Role of the host currently in use";
      };

      options.name = lib.mkOption {
        type = lib.types.str;
        description = "Config name currently in use";
      };
    };

  hostOf = name: c: cfg.builders.host (if c.host == null then name else c.host);

  metaOf =
    name: c:
    cfg.builders.mkMeta {
      inherit name;
      inherit (c) profile;
      host = hostOf name c;
      extra.standalone = true;
    };

  rootModulesOf = meta: (cfg.resolve meta).rootHome or [ ];

  # Shared by both modes so they always evaluate the same module list.
  mkModules =
    {
      meta,
      host,
      extraModules ? [ ],
    }:
    cfg.homeModules
    ++ extraModules
    ++ (cfg.resolve meta).home or [ ]
    ++ cfg.builders.hostModules host "home"
    ++ [
      "${cfg.paths.modules}/home"
      cfg.builders.roleFlagsModule
      configOptions
      meta
    ];

  # Root only gets the rootHome modules, never the per-user home or desktop.
  mkRootModules =
    { meta }:
    cfg.homeModules
    ++ rootModulesOf meta
    ++ [
      cfg.builders.roleFlagsModule
      configOptions
      meta
    ];

  mkStandalone =
    name: c:
    let
      host = hostOf name c;
      # Memoized per system by flake-parts when the system is in `systems`
      base = cfg.pureBase.mkBase { inherit (host) system; } // {
        inherit host;
      };
      meta = base.configMeta.home.${name};
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit (base) pkgs;
      # specialArgs are resolved before `config`, so modules can use them
      # in `imports` (e.g. `base.inputs.sops-nix.homeManagerModules.sops`).
      extraSpecialArgs = base.extraSpecialArgs // {
        inherit base host meta;
      };

      modules = mkModules {
        inherit meta host;
        inherit (c) extraModules;
      };
    };

  # Called from the NixOS side with that config's own base, host and meta
  mkNonStandalone =
    {
      meta,
      base,
      host,
      username,
      withRoot ? true,
      ...
    }:
    let
      homeMeta = meta // {
        standalone = false;
      };
      # withRoot is checked first so hosts that disable root never touch rootHome
      hasRoot = withRoot && username != "root" && rootModulesOf homeMeta != [ ];
    in
    {
      # pkgs (with all overlays) comes from the NixOS config, which is
      # nixpkgs.pkgs = base.pkgs, so both sides share one instance.
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      extraSpecialArgs = {
        inherit base host;
        meta = homeMeta;
        inherit (base) inputs;
      };

      users = {
        ${username}.imports = mkModules {
          meta = homeMeta;
          inherit host;
        };
      }
      // lib.optionalAttrs hasRoot {
        root.imports = mkRootModules { meta = homeMeta; };
      };
    };
in
{
  options = {
    # Modules added to every home-manager configuration
    homeModules = mkOption {
      type = types.listOf types.raw;
      default = [ ];
    };

    home = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Key in hosts.<name> to use, defaults to the name of this configuration";
            };
            profile = mkOption { type = types.str; };
            extraModules = mkOption {
              type = types.listOf types.raw;
              default = [ ];
            };
          };
        }
      );
      default = { };
    };
  };

  config = {
    flake.homeConfigurations = lib.mapAttrs mkStandalone cfg.home;

    base.pure.configMeta.home = lib.mapAttrs metaOf cfg.home;

    builders = {
      mkHomeNonStandalone = mkNonStandalone;
      mkHomeStandalone = mkStandalone;
    };
  };
}
