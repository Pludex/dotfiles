{
  config,
  lib,
  pkgs,
  ...
}:
let
  ports = {
    playwright = 8931;
    context7 = 8932;
    fetch = 8933;
    github = 8934;
    filesystem = 8935;
  };

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
    name: cmd:
    "${uvx} mcp-proxy --host 127.0.0.1 --port ${toString ports.${name}} --stateless --pass-environment -- ${cmd}";

  mcpServers = {
    playwright = {
      exec = lib.concatStringsSep " " [
        npx
        "-y @playwright/mcp@latest"
        "--headless --browser chromium"
        "--executable-path ${lib.getExe pkgs.chromium}"
        "--host localhost --port ${toString ports.playwright}"
      ];
      env = [
        "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
        "PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true"
      ];
    };

    context7.exec = bridge "context7" "${npx} -y @upstash/context7-mcp";

    fetch.exec = bridge "fetch" "${uvx} mcp-server-fetch";

    github = {
      exec = bridge "github" "${lib.getExe pkgs.github-mcp-server} stdio --read-only --toolsets=repos,issues,pull_requests";
      envFile = config.sops.templates."mcp-github.env".path;
    };

    filesystem.exec = bridge "filesystem" "${npx} -y @modelcontextprotocol/server-filesystem /workspaces";
  };

  mkMcpService =
    name:
    {
      exec,
      env ? [ ],
      envFile ? null,
    }:
    lib.nameValuePair "mcp-${name}" {
      Unit = {
        Description = "MCP ${name} (HTTP)";
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
        ]
        ++ env;
      }
      // lib.optionalAttrs (envFile != null) { EnvironmentFile = envFile; };
      Install.WantedBy = [ "default.target" ];
    };
in
{
  options.my.mcp.endpoints = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    readOnly = true;
    description = "Streamable HTTP URL of each shared MCP server, keyed by name.";
  };

  config = {
    my.mcp.endpoints = lib.mapAttrs (_: port: "http://127.0.0.1:${toString port}/mcp") ports // {
      basic-memory = "http://127.0.0.1:8765/mcp";
    };

    sops.secrets."api-keys/github-mcp" = { };

    sops.templates."mcp-github.env".content = ''
      GITHUB_PERSONAL_ACCESS_TOKEN=${config.sops.placeholder."api-keys/github-mcp"}
    '';

    systemd.user.services = lib.mapAttrs' mkMcpService mcpServers;
  };
}
