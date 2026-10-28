{ config, pkgs, ... }:
let
  port = 3210;
  dataDir = "%h/.local/share/open-webui";
  secretName = "api-keys/omniroute/open-webui";
in
{
  sops.secrets.${secretName} = { };

  sops.templates."open-webui.env".content = ''
    OPENAI_API_KEY=${config.sops.placeholder.${secretName}}
    TOOL_SERVER_CONNECTIONS='[{"type":"mcp","url":"http://127.0.0.1:8765/mcp","auth_type":"none","key":"","config":{"enable":true},"info":{"id":"basic-memory","name":"Basic Memory","description":"Shared long-term memory"}}]'
  '';

  home.packages = [ pkgs.open-webui ];

  systemd.user.services.open-webui = {
    Unit = {
      Description = "Open WebUI";
      After = [
        "network.target"
        "sops-nix.service"
      ];
    };

    Service = {
      ExecStart = "${pkgs.open-webui}/bin/open-webui serve --host 127.0.0.1 --port ${toString port}";
      Restart = "on-failure";
      RestartSec = 5;

      Environment = [
        "DATA_DIR=${dataDir}"
        "OPENAI_API_BASE_URL=http://localhost:20128/v1"
        "ENABLE_OLLAMA_API=False"
        "ENABLE_PERSISTENT_CONFIG=False"
        "ANONYMIZED_TELEMETRY=False"
        "DO_NOT_TRACK=True"
        "SCARF_NO_ANALYTICS=True"
      ];

      EnvironmentFile = config.sops.templates."open-webui.env".path;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
