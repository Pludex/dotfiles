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
        profile = mkStrOption "Profile name currently in use";
        host = mkStrOption "Host name currently in use";
        name = mkStrOption "Config name currently in use";
        desktop = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum (lib.attrNames cfg.desktops));
          description = "Desktop name currently in use, null when headless";
        };
        role = lib.mkOption {
          type = lib.types.enum (lib.attrNames cfg.roles);
          description = "Role of the host currently in use";
        };
      };
    };

  nixosConfigOf = name: cfg.nixos.${name} or (throw "builder: nixos.${name} is not defined");

  hostOf = name: c: cfg.builders.host (if c.host == null then name else c.host);

  metaOf =
    name: c:
    cfg.builders.mkMeta {
      inherit name;
      inherit (c) profile;
      host = hostOf name c;
    };

  contextOf =
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
      inherit (contextOf name c) host base meta;
    in
    base.extraSpecialArgs // { inherit base host meta; };

  mkNixosModules =
    name: c:
    let
      inherit (contextOf name c) host base meta;
      inherit (base) paths;
      resolved = cfg.resolve meta;
    in
    cfg.nixosModules
    ++ cfg.builders.hostModules host "nixos"
    ++ (resolved.nixos or [ ])
    ++ c.extraModules
    ++ [
      "${paths.modules}/nixos"
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
            withRoot = mkOption {
              type = types.bool;
              default = true;
              description = "Embed the rootHome modules as home-manager.users.root";
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
