{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 3211;
  podman = lib.getExe pkgs.podman;
  uvx = lib.getExe' pkgs.uv "uvx";
  npx = lib.getExe' pkgs.nodejs "npx";

  mcpPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.uv
    pkgs.git
    pkgs.python3
    pkgs.bash
    pkgs.coreutils
  ];

  bridge =
    mcpPort: cmd:
    "${uvx} mcp-proxy --host 127.0.0.1 --port ${toString mcpPort} --stateless --pass-environment -- ${cmd}";

  mcpServers = {
    playwright = {
      exec = lib.concatStringsSep " " [
        npx
        "-y @playwright/mcp@latest"
        "--headless --browser chromium"
        "--executable-path ${lib.getExe pkgs.chromium}"
        "--host 127.0.0.1 --port 8931"
      ];
      env = [
        "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
        "PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true"
      ];
    };

    context7.exec = bridge 8932 "${npx} -y @upstash/context7-mcp";

    fetch.exec = bridge 8933 "${uvx} mcp-server-fetch";

    github = {
      exec = bridge 8934 "${lib.getExe pkgs.github-mcp-server} stdio --read-only --toolsets=repos,issues,pull_requests";
      envFile = config.sops.templates."lobechat-github.env".path;
    };

    filesystem.exec = bridge 8935 "${npx} -y @modelcontextprotocol/server-filesystem /workspaces";
  };

  mkMcpService =
    name:
    {
      exec,
      env ? [ ],
      envFile ? null,
    }:
    lib.nameValuePair "lobechat-mcp-${name}" {
      Unit = {
        Description = "MCP ${name} (HTTP) for LobeChat";
        After = [
          "network.target"
          "sops-nix.service"
        ];
      };
      Service = {
        ExecStart = exec;
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "PATH=${mcpPath}"
          "UV_PYTHON_DOWNLOADS=never"
          "UV_PYTHON=${lib.getExe pkgs.python3}"
        ] ++ env;
      } // lib.optionalAttrs (envFile != null) { EnvironmentFile = envFile; };
      Install.WantedBy = [ "default.target" ];
    };
in
{
  sops.secrets = {
    "api-keys/omniroute/lobehub" = { };
    "api-keys/github-mcp" = { };
  };

  sops.templates."lobechat.env".content = ''
    OPENAI_API_KEY=${config.sops.placeholder."api-keys/omniroute/lobehub"}
  '';

  sops.templates."lobechat-github.env".content = ''
    GITHUB_PERSONAL_ACCESS_TOKEN=${config.sops.placeholder."api-keys/github-mcp"}
  '';

  systemd.user.services = lib.mapAttrs' mkMcpService mcpServers // {
    lobechat = {
      Unit = {
        Description = "LobeChat";
        After = [
          "network.target"
          "sops-nix.service"
        ];
      };
      Service = {
        Environment = [ "PATH=/run/wrappers/bin:${lib.makeBinPath [ pkgs.coreutils ]}" ];
        ExecStartPre = "-${podman} rm -f lobechat";
        ExecStart = lib.concatStringsSep " " [
          podman
          "run --rm --name lobechat --network=host"
          "--env-file ${config.sops.templates."lobechat.env".path}"
          "-e HOSTNAME=127.0.0.1"
          "-e PORT=${toString port}"
          "-e OPENAI_PROXY_URL=http://127.0.0.1:20128/v1"
          "docker.io/lobehub/lobe-chat:latest"
        ];
        ExecStop = "${podman} stop lobechat";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 600;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
