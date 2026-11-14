{
  imports = [ ];

  modules.home.services = {
    aider = {
      programs.aider-chat = {
        enable = true;
        settings = {
          auto-commits = true;
          dark-mode = true;
        };
      };
    };

    audio-manager =
      { pkgs, base, ... }:
      {
        systemd.user.services.audio-manager = {
          Unit = {
            Description = "Smart Audio Ducking Service (PipeWire/WirePlumber)";
            After = [
              "pipewire.service"
              "wireplumber.service"
            ];
            Wants = [
              "pipewire.service"
              "wireplumber.service"
            ];
          };

          Service = {
            Type = "simple";
            ExecStart = ''
              ${pkgs.myPkgs.audio-manager}/bin/audio-manager --primary ${base.players.music} --blacklist chromium
            '';

            Restart = "on-failure";
            RestartSec = "5s";

            StandardOutput = "journal";
            StandardError = "journal";
          };

          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };

    espanso = {
      services.espanso = {
        enable = true;

        configs = {
          auto_restarts = true;
          prefixKey = ":";
        };
      };
    };

    open-webui =
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
      };

    basic-memory = ./basic-memory.nix;
    librechat = ./librechat.nix;
    lobehub = ./lobehub.nix;
  };
}
