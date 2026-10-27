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

  nixosConfigOf = name: cfg.nixos.${name} or (throw "builder: nixos.${name} is not defined");

  resolve =
    name: c:
    let
      hostName = if c.host == null then name else c.host;
      host = cfg.builder.host hostName;
      base = cfg.base.forSystem host.system // {
        inherit host;
      };
      meta = {
        inherit name;
        inherit (c) desktop profile;
        host = host.name;
      };
    in
    {
      inherit host base meta;
    };

  mkNixosSpecialArgs =
    name: c:
    let
      inherit (resolve name c) host base meta;
    in
    {
      inherit base host meta;
    } // base.extraArgs;

  mkNixosModules =
    name: c:
    let
      inherit (resolve name c) host base meta;
      inherit (base) paths;
    in
    cfg.nixosModules
    ++ cfg.builder.hostModules host "nixos"
    ++ config.profilesResult.${c.profile}.nixos
    ++ c.extraModules
    ++ [
      "${paths.modules}/nixos"
      (import paths.desktops { inherit (c) desktop; }).nixos
      configOptions
      (meta // { networking.hostName = lib.mkDefault host.name; })
      { nixpkgs.pkgs = base.pkgs; }
    ]
    ++ lib.optionals host.withHome [
      inputs.home-manager.nixosModules.home-manager
      (
        { config, ... }:
        {
          home-manager = base.mkHomeNonStandalone {
            inherit
              config
              base
              host
              meta
              ;
            inherit (c) withRoot;
            username = if (!config.isContainer) then base.username else (base.app name).username;
          };
        }
      )
    ];

  nixosModulesOf = name: mkNixosModules name (nixosConfigOf name);
  nixosSpecialArgsOf = name: mkNixosSpecialArgs name (nixosConfigOf name);

  mkSystem =
    name: c:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = mkNixosSpecialArgs name c;
      modules = mkNixosModules name c;
    };
in
{
  options = {
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
            withRoot = mkOption {
              type = types.bool;
              default = true;
              description = "Embed the profile's rootHome modules as home-manager.users.root";
            };
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

    builder = {
      mkNixos = mkSystem;
      mkNixosModules = mkNixosModules;
      mkNixosSpecialArgs = mkNixosSpecialArgs;
      inherit nixosModulesOf nixosSpecialArgsOf;
    };
  };
}
