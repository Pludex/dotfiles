{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  hostModule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          description = "Host name, taken from the attribute name in hosts.<name>";
        };

        system = mkOption {
          type = types.str;
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
          default = [ ];
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
    hostOf = name: cfg.hosts.${name} or (throw "Unknown host '${name}'");

    # Empty when host is null or has no module for this framework
    hostModules =
      host: framework: lib.optional (host != null && host.modules ? ${framework}) host.modules.${framework};
  };
}
