{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 3080;
  mongoDir = "${config.xdg.dataHome}/librechat/mongodb";
  yaml = pkgs.formats.yaml { };

  npx = lib.getExe' pkgs.nodejs "npx";
  uvx = lib.getExe' pkgs.uv "uvx";

  librechatConfig = yaml.generate "librechat.yaml" {
    version = "1.2.8";

    endpoints.custom = [
      {
        name = "OmniRoute";
        apiKey = "\${OMNIROUTE_API_KEY}";
        baseURL = "http://localhost:20128/v1";
        models = {
          default = [ "auto" ];
          fetch = true;
        };
        titleConvo = true;
        titleModel = "auto";
        modelDisplayLabel = "OmniRoute";
      }
    ];

    mcpServers = {
      basic-memory = {
        type = "streamable-http";
        url = "http://127.0.0.1:8765/mcp";
        title = "Basic Memory";
      };

      fetch = {
        type = "stdio";
        title = "Fetch";
        command = uvx;
        args = [ "mcp-server-fetch" ];
        env = {
          UV_PYTHON_DOWNLOADS = "never";
          UV_PYTHON = lib.getExe pkgs.python3;
        };
      };

      github = {
        type = "stdio";
        title = "GitHub";
        command = lib.getExe pkgs.github-mcp-server;
        args = [
          "stdio"
          "--read-only"
          "--toolsets=repos,issues,pull_requests"
        ];
        env.GITHUB_PERSONAL_ACCESS_TOKEN = "\${GITHUB_MCP_TOKEN}";
      };

      context7 = {
        type = "stdio";
        title = "Context7";
        command = npx;
        args = [
          "-y"
          "@upstash/context7-mcp"
        ];
      };

      filesystem = {
        type = "stdio";
        title = "Filesystem";
        command = npx;
        args = [
          "-y"
          "@modelcontextprotocol/server-filesystem"
          "/workspaces"
        ];
      };
    };

    mcpSettings.allowedDomains = [ "127.0.0.1:8765" ];
  };
in
{
  sops.secrets = {
    "librechat/creds-key" = { };
    "librechat/creds-iv" = { };
    "librechat/jwt-secret" = { };
    "librechat/jwt-refresh-secret" = { };
    "api-keys/omniroute/librechat" = { };
    "api-keys/github-mcp" = { };
  };

  sops.templates."librechat.env".content = ''
    CREDS_KEY=${config.sops.placeholder."librechat/creds-key"}
    CREDS_IV=${config.sops.placeholder."librechat/creds-iv"}
    JWT_SECRET=${config.sops.placeholder."librechat/jwt-secret"}
    JWT_REFRESH_SECRET=${config.sops.placeholder."librechat/jwt-refresh-secret"}
    OMNIROUTE_API_KEY=${config.sops.placeholder."api-keys/omniroute/librechat"}
    GITHUB_MCP_TOKEN=${config.sops.placeholder."api-keys/github-mcp"}
  '';

  systemd.user.services.librechat-mongodb = {
    Unit.Description = "MongoDB for LibreChat";
    Service = {
      ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p ${mongoDir}";
      ExecStart = "${lib.getExe' pkgs.mongodb "mongod"} --dbpath ${mongoDir} --bind_ip 127.0.0.1 --port 27017";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.librechat = {
    Unit = {
      Description = "LibreChat";
      After = [
        "network.target"
        "sops-nix.service"
        "librechat-mongodb.service"
      ];
      Requires = [ "librechat-mongodb.service" ];
    };
    Service = {
      ExecStart = lib.getExe' pkgs.librechat "librechat-server";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOST=127.0.0.1"
        "PORT=${toString port}"
        "MONGO_URI=mongodb://127.0.0.1:27017/LibreChat"
        "CONFIG_PATH=${librechatConfig}"
        "ALLOW_REGISTRATION=true"
        "MCP_ALLOWED_DOMAINS=http://127.0.0.1:8765,http://localhost:8765"
        "PATH=${
          lib.makeBinPath [
            pkgs.nodejs
            pkgs.uv
            pkgs.git
            pkgs.python3
            pkgs.bash
            pkgs.coreutils
          ]
        }"
      ];
      EnvironmentFile = config.sops.templates."librechat.env".path;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
