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
        type = lib.types.str;
        description = "Desktop name currently in use";
      };

      options.host = lib.mkOption {
        type = lib.types.str;
        description = "Host name currently in use";
      };

      options.name = lib.mkOption {
        type = lib.types.str;
        description = "Config name currently in use";
      };
    };

  # Shared by both modes so they always evaluate the same module list.
  mkModules =
    {
      meta,
      host,
      extraModules ? [ ],
    }:
    cfg.homeModules
    ++ extraModules
    ++ cfg.profilesResult.${meta.profile}.home
    ++ cfg.builder.hostModules host "home"
    ++ [
      "${cfg.paths.modules}/home"
      (import cfg.paths.desktops { inherit (meta) desktop; }).home
      configOptions
      meta
    ];

  # Root only gets the profile's rootHome modules, never the per-user home or desktop.
  mkRootModules =
    { meta }:
    cfg.homeModules
    ++ (cfg.profilesResult.${meta.profile}.rootHome or [ ])
    ++ [
      configOptions
      meta
    ];

  mkStandalone =
    name: c:
    let
      hostName = if c.host == null then name else c.host;
      host = cfg.builder.hostOf hostName;
      # Base of this host's architecture, memoized per system by flake-parts
      base = cfg.base.forSystem host.system // {
        inherit host;
      };
      meta = {
        inherit name;
        inherit (c) profile desktop;
        host = host.name;
        standalone = true;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = base.pkgs;
      # specialArgs are resolved before `config`, so modules can use them
      # in `imports` (e.g. `base.inputs.sops-nix.homeManagerModules.sops`).
      extraSpecialArgs = {
        inherit base host meta;
        inherit (base) inputs;
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
      hasRoot =
        withRoot && username != "root" && (cfg.profilesResult.${meta.profile}.rootHome or [ ]) != [ ];
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
            desktop = mkOption { type = types.str; };
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
    builder.mkHomeNonStandalone = mkNonStandalone;
    builder.mkHomeStandalone = mkStandalone;
  };
}
