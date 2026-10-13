{ config, inputs, ... }:
let
  omnirouteKey = config.sops.placeholder."api-keys/omniroute/hermes";
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default ];

  sops.secrets."api-keys/omniroute/hermes" = { };
  sops.secrets."api-keys/hermes/api-server" = { };

  sops.templates."hermes-env".content = ''
    OPENAI_API_KEY=${omnirouteKey}
    OMNIROUTE_API_KEY=${omnirouteKey}
    API_SERVER_KEY=${config.sops.placeholder."api-keys/hermes/api-server"}
  '';

  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;
    gateway.enable = true;

    settings.model = {
      base_url = "http://localhost:20128/v1";
      default = "antigravity/gemini-3.1-flash-lite";
    };

    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = "8642";
    };
    environmentFiles = [ config.sops.templates."hermes-env".path ];

    mcpServers.omniroute = {
      url = "http://127.0.0.1:20128/api/mcp/stream";
      headers.Authorization = "Bearer \${OMNIROUTE_API_KEY}";
    };
  };

  systemd.user.services.hermes-agent.Unit = {
    After = [ "omniroute.service" ];
    Wants = [ "omniroute.service" ];
  };
}
