{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  # Parent modules come first so the child can override them
  hostModules =
    host: framework:
    lib.optionals (host != null) (
      lib.optionals (host.extends != null) (hostModules cfg.hosts.${host.extends} framework)
      ++ lib.optional (host.modules ? ${framework}) host.modules.${framework}
    );

  hostModule =
    { name, config, ... }:
    let
      parent = if config.extends == null then null else cfg.hosts.${config.extends};
    in
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          description = "Host name, taken from the attribute name in hosts.<name>";
        };

        extends = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Host to inherit system, gpus and modules from";
        };

        withHome = mkOption {
          type = types.bool;
          default = true;
          description = "Whether home-manager is enabled for this host";
        };

        system = mkOption {
          type = types.str;
          default = if parent != null then parent.system else throw "hosts.${name}.system is not set";
          example = "x86_64-linux";
          description = "System architecture of this host";
        };

        gpus = mkOption {
          type = types.listOf (
            types.enum [
              "intel"
              "amd"
              "nvidia"
            ]
          );
          default = if parent != null then parent.gpus else [ ];
          description = "GPU vendors available on this host";
        };

        modules = mkOption {
          type = types.attrsOf types.deferredModule;
          default = { };
          example = lib.literalExpression "{ nixos = { pkgs, ... }: { }; home = { ... }: { }; }";
          description = "Modules keyed by framework name (nixos, home, nixvim, ...)";
        };
      };
    };
in
{
  options.hosts = mkOption {
    type = types.attrsOf (types.submodule hostModule);
    default = { };
    description = "Host definitions shared by every framework";
  };

  config.builder = {
    host = name: cfg.hosts.${name} or (throw "Unknown host '${name}'");
    inherit hostModules;
  };
}
