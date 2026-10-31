{
  lib,
  pkgs,
  base,
  inputs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;

  yamlFormat = pkgs.formats.yaml { };

  mcpServerModule = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      url = mkOption { type = types.str; };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "HTTP headers; may reference env vars as \${NAME}.";
      };
      secretEnv = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "ENV_VAR -> sops secret name, exported to every instance that uses this server.";
      };
    };
  };

  # Shared by the main instance and every profile
  instanceOptions = {
    model = mkOption { type = types.str; };
    apiKeySecret = mkOption {
      type = types.str;
      description = "sops secret holding the omniroute API key.";
    };
    discord = {
      tokenSecret = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      homeChannel = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      homeChannelName = mkOption {
        type = types.str;
        default = "";
      };
      freeChannels = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
    mcp = mkOption {
      type = types.attrsOf (types.submodule mcpServerModule);
      default = { };
      description = "Servers for this instance; override global ones by name.";
    };
    excludeMcp = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Global MCP servers this instance must not get.";
    };
    env = mkOption {
      type = types.attrsOf types.str;
      default = { };
    };
    secretEnv = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "ENV_VAR -> sops secret name.";
    };
    settings = mkOption {
      type = yamlFormat.type;
      default = { };
      description = "Extra config.yaml settings, merged recursively.";
    };
  };
in
{
  options.services.hermes-agent-backend = {
    enable = mkEnableOption "hermes-agent backend (main instance, profiles, omh)";

    package = mkOption {
      type = types.package;
      default = pkgs.hermes.full;
    };
    hermesHome = mkOption {
      type = types.str;
      default = "/app/data";
    };
    omniroute.baseUrl = mkOption {
      type = types.str;
      default = (base.app "omniroute").baseUrl;
    };

    sessionTokenSecret = mkOption { type = types.str; };
    allowedUsersSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "sops secret exported as DISCORD_ALLOWED_USERS where discord is configured.";
    };

    apiServer = {
      enable = mkEnableOption "hermes API server on the main instance";
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
      };
      port = mkOption {
        type = types.port;
        default = (base.app "hermes-agent").port;
      };
    };

    mcp = mkOption {
      type = types.attrsOf (types.submodule mcpServerModule);
      default = { };
      description = "MCP servers applied to the main instance and every profile.";
    };

    main = mkOption {
      type = types.submodule { options = instanceOptions; };
    };

    profiles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = instanceOptions // {
            enable = mkOption {
              type = types.bool;
              default = true;
            };
          };
        }
      );
      default = { };
    };

    omh = {
      enable = mkEnableOption "oh-my-hermes";
      package = mkOption {
        type = types.package;
        default = base.myPkgs.oh-my-hermes;
      };
      syncInterval = mkOption {
        type = types.str;
        default = "1h";
      };
      chains = mkOption {
        type = types.attrsOf (
          types.listOf (
            types.submodule {
              options = {
                model = mkOption { type = types.str; };
                reasoningEffort = mkOption { type = types.str; };
              };
            }
          )
        );
        default = { };
        description = "Routing category -> model chain.";
      };
    };

    themePack = {
      enable = mkEnableOption "Hermes desktop theme pack";
      src = mkOption {
        type = types.path;
        default = inputs.hermes-desktop-theme-pack;
      };
    };
  };
}
