{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;

  str = mkOption { type = types.str; };

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
      extraModules ? [ ],
    }:
    cfg.homeModules
    ++ extraModules
    ++ [
      "${cfg.paths.modules}/home"
      (import cfg.paths.profiles { inherit profile; }).home
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
      # Base of this config's architecture, memoized per system by flake-parts
      base = cfg.base.forSystem c.system;
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = base.pkgs;
      # specialArgs are resolved before `config`, so modules can use them
      # in `imports` (e.g. `base.inputs.sops-nix.homeManagerModules.sops`).
      extraSpecialArgs = {
        inherit base;
        inherit (base) inputs;
      };

      modules = mkModules {
        inherit name;
        inherit (c) profile desktop extraModules;
        standalone = true;
      };
    };

  # Called from the NixOS side with that config's own base
  mkNonStandalone =
    { config, base, ... }:
    {
      # pkgs (with all overlays) comes from the NixOS config, which is
      # nixpkgs.pkgs = base.pkgs, so both sides share one instance.
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      extraSpecialArgs = { inherit base; inherit (base) inputs; };

      users.${base.username}.imports = mkModules {
        inherit (config) name profile desktop;
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
            system = str;
            profile = str;
            desktop = str;
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
