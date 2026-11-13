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
        role = lib.mkOption {
          type = lib.types.enum cfg.roles;
          description = "Role of the host currently in use";
        };
      };
    };

  nixosConfigOf = name: cfg.nixos.${name} or (throw "builder: nixos.${name} is not defined");

  hostOf = name: c: cfg.builders.host (if c.host == null then name else c.host);

  metaOf =
    name: c:
    let
      host = hostOf name c;
    in
    {
      inherit name;
      inherit (c) desktop profile;
      host = host.name;
      inherit (host) role;
    }
    // cfg.builders.roleFlags host.role;

  resolve =
    name: c:
    let
      host = hostOf name c;
      base = (cfg.pureBase.mkBase { inherit (host) system; }) // {
        inherit host;
      };
    in
    {
      inherit host base;
      meta = base.configMeta.nixos.${name};
    };

  mkNixosSpecialArgs =
    name: c:
    let
      inherit (resolve name c) host base meta;
    in
    {
      inherit base host meta;
    }
    // base.extraSpecialArgs;

  mkNixosModules =
    name: c:
    let
      inherit (resolve name c) host base meta;
      inherit (base) paths;
    in
    cfg.nixosModules
    ++ cfg.builders.hostModules host "nixos"
    ++ config.profilesResult.${c.profile}.nixos
    ++ c.extraModules
    ++ [
      "${paths.modules}/nixos"
      (import paths.desktops { inherit (c) desktop; }).nixos
      cfg.builders.roleFlagsModule
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
            username = if meta.isContainer then (base.app name).username else base.username;
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

    base.pure.configMeta.nixos = lib.mapAttrs metaOf cfg.nixos;

    builders = {
      mkNixos = mkSystem;
      inherit mkNixosModules;
      inherit mkNixosSpecialArgs;
      inherit nixosModulesOf nixosSpecialArgsOf;
    };
  };
}
