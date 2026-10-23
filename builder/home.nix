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

      options.name = lib.mkOption {
        type = lib.types.str;
        description = "Config name currently in use";
      };
    };

  # Shared by both modes so they always evaluate the same module list.
  mkModules =
    {
      standalone,
      name,
      profile,
      desktop,
      host,
      extraModules ? [ ],
    }:
    cfg.homeModules
    ++ extraModules
    ++ config.profilesResult.${profile}.home
    ++ cfg.builder.hostModules host "home"
    ++ [
      "${cfg.paths.modules}/home"
      (import cfg.paths.desktops { inherit desktop; }).home
      configOptions
      {
        inherit
          standalone
          profile
          desktop
          name
          ;
      }
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
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = base.pkgs;
      # specialArgs are resolved before `config`, so modules can use them
      # in `imports` (e.g. `base.inputs.sops-nix.homeManagerModules.sops`).
      extraSpecialArgs = {
        inherit base host;
        inherit (base) inputs;
      };

      modules = mkModules {
        inherit name host;
        inherit (c) profile desktop extraModules;
        standalone = true;
      };
    };

  # Called from the NixOS side with that config's own base and host
  mkNonStandalone =
    {
      config,
      base,
      host,
      username,
      ...
    }:
    {
      # pkgs (with all overlays) comes from the NixOS config, which is
      # nixpkgs.pkgs = base.pkgs, so both sides share one instance.
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      extraSpecialArgs = {
        inherit base host;
        inherit (base) inputs;
      };

      users.${username}.imports = mkModules {
        inherit (config) name profile desktop;
        inherit host;
        standalone = false;
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
