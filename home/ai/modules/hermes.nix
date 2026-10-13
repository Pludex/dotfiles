{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.hermes;
  sopsRef = config.sops.placeholder;

  settings = lib.recursiveUpdate {
    model = {
      provider = "custom";
      default = cfg.model;
      base_url = cfg.baseUrl;
      api_key = sopsRef.${cfg.apiKeySecret};
    };
    mcp_servers = lib.optionalAttrs cfg.omnirouteMcp.enable {
      omniroute = {
        url = cfg.omnirouteMcp.url;
        headers.Authorization = "Bearer ${sopsRef.${cfg.apiKeySecret}}";
      };
    };
  } cfg.settings;
in
{
  options.services.hermes = {
    enable = mkEnableOption "Hermes Agent gateway";

    package = mkOption {
      type = types.package;
      description = "Package providing the `hermes` binary.";
    };

    baseUrl = mkOption {
      type = types.str;
      default = "http://localhost:20128/v1";
      description = "OpenAI-compatible endpoint used for model calls (OmniRoute).";
    };

    model = mkOption {
      type = types.str;
      default = "auto";
      description = "Default model or combo name served by OmniRoute.";
    };

    apiKeySecret = mkOption {
      type = types.str;
      default = "api-keys/omniroute/hermers";
      description = "sops secret holding the OmniRoute API key (read/write scope).";
    };

    omnirouteMcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Register the OmniRoute MCP server so Hermes can manage the gateway.";
      };
      url = mkOption {
        type = types.str;
        default = "http://127.0.0.1:20128/api/mcp/stream";
        description = "OmniRoute MCP streamable HTTP endpoint.";
      };
    };

    apiServer = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose the OpenAI-compatible API server of the gateway.";
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Bind address of the API server.";
      };
      port = mkOption {
        type = types.port;
        default = 8642;
        description = "Port of the API server.";
      };
      keySecret = mkOption {
        type = types.str;
        default = "api-keys/hermes/api-server";
        description = "sops secret holding the bearer token clients must send (16+ characters).";
      };
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra config.yaml settings, deep-merged over the generated ones.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    sops.secrets = lib.mkMerge [
      { ${cfg.apiKeySecret} = { }; }
      (mkIf cfg.apiServer.enable { ${cfg.apiServer.keySecret} = { }; })
    ];

    sops.templates."hermes-config.yaml".content = builtins.toJSON settings;

    sops.templates."hermes-env" = mkIf cfg.apiServer.enable {
      content = ''
        API_SERVER_ENABLED=true
        API_SERVER_HOST=${cfg.apiServer.host}
        API_SERVER_PORT=${toString cfg.apiServer.port}
        API_SERVER_KEY=${sopsRef.${cfg.apiServer.keySecret}}
      '';
    };

    systemd.user.services.hermes = {
      Unit = {
        Description = "Hermes Agent gateway";
        After = [
          "sops-nix.service"
          "omniroute.service"
        ];
        Wants = [ "sops-nix.service" ];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/install -Dm600 ${
          config.sops.templates."hermes-config.yaml".path
        } %h/.hermes/config.yaml";
        ExecStart = "${cfg.package}/bin/hermes gateway run";
        EnvironmentFile = lib.optional cfg.apiServer.enable config.sops.templates."hermes-env".path;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
