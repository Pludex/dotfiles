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
    let
      mkStrOption =
        description:
        lib.mkOption {
          type = lib.types.str;
          inherit description;
        };
    in
    {
      options = {
        desktop = mkStrOption "Desktop name currently in use";
        profile = mkStrOption "Profile name currently in use";
        host = mkStrOption "Host name currently in use";
        name = mkStrOption "Config name currently in use";
      };
    };

  mkSystem =
    name: c:
    let
      # Base of this config's architecture, memoized per system by flake-parts
      base = cfg.base.forSystem c.system;
      inherit (base) paths;
    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit base;
        inherit (base) inputs;
      };
      modules =
        cfg.nixosModules
        ++ c.extraModules
        ++ [
          "${paths.modules}/nixos"
          (import paths.hosts { inherit (c) host; })
          (import paths.profiles { inherit (c) profile; }).nixos
          (import paths.desktops { inherit (c) desktop; }).nixos
          inputs.home-manager.nixosModules.home-manager
          configOptions
          {
            inherit (c) desktop profile host;
            inherit name;
          }
          # nixpkgs.config is ignored once nixpkgs.pkgs is set; overlays would be appended on top
          { nixpkgs.pkgs = base.pkgs; }
          # Reads profile/desktop/name back from this config
          (
            { config, ... }:
            {
              home-manager = base.mkHomeNonStandalone { inherit config base; };
            }
          )
        ];
    };
in
{
  options = {
    # Modules added to every NixOS configuration
    nixosModules = mkOption {
      type = types.listOf types.raw;
      default = [ ];
    };

    nixos = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            host = str;
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
    flake.nixosConfigurations = lib.mapAttrs mkSystem cfg.nixos;
    builder.mkNixos = mkSystem;
  };
}
