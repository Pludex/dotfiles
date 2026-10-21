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
      hostName = if c.host == null then name else c.host;
      host = cfg.builder.hostOf hostName;
      # Base of this host's architecture, memoized per system by flake-parts
      base = cfg.base.forSystem host.system // {
        inherit host;
      };
      inherit (base) paths;
    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit base host;
        inherit (base) inputs;
      };
      modules =
        cfg.nixosModules
        ++ c.extraModules
        ++ config.profilesResult.${c.profile}.nixos
        ++ cfg.builder.hostModules host "nixos"
        ++ [
          "${paths.modules}/nixos"
          (import paths.desktops { inherit (c) desktop; }).nixos
          inputs.home-manager.nixosModules.home-manager
          configOptions
          {
            inherit (c) desktop profile;
            inherit name;
            host = host.name;
            networking.hostName = lib.mkDefault host.name;
          }
          # nixpkgs.config is ignored once nixpkgs.pkgs is set; overlays would be appended on top
          { nixpkgs.pkgs = base.pkgs; }
          # Reads profile/desktop/name back from this config
          (
            { config, ... }:
            {
              home-manager = base.mkHomeNonStandalone { inherit config base host; };
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
    flake.nixosConfigurations = lib.mapAttrs mkSystem cfg.nixos;
    builder.mkNixos = mkSystem;
  };
}
