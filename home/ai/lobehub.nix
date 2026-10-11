{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 3211;
  pgPort = 5433;
  redisPort = 6380;
  redisDir = "${config.xdg.dataHome}/lobehub/redis";

  podman = lib.getExe pkgs.podman;
  appImage = "docker.io/lobehub/lobehub:latest";
  pgImage = "docker.io/paradedb/paradedb:0.25.9-pg17";
  podmanPath = "/run/wrappers/bin:${lib.makeBinPath [ pkgs.coreutils ]}";

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
      envFile = config.sops.templates."lobehub-github.env".path;
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
    lib.nameValuePair "lobehub-mcp-${name}" {
      Unit = {
        Description = "MCP ${name} (HTTP) for LobeHub";
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

  waitPostgres = pkgs.writeShellScript "lobehub-wait-postgres" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
      ${pkgs.postgresql_17}/bin/pg_isready -q -h 127.0.0.1 -p ${toString pgPort} && exit 0
      ${pkgs.coreutils}/bin/sleep 1
    done
    exit 1
  '';

  containerEnv = {
    HOSTNAME = "127.0.0.1";
    PORT = toString port;
    APP_URL = "http://localhost:${toString port}";
    DATABASE_DRIVER = "node";
    REDIS_URL = "redis://127.0.0.1:${toString redisPort}";
    OPENAI_PROXY_URL = "http://127.0.0.1:20128/v1";
    OPENAI_MODEL_LIST = "+auto";
    SSRF_ALLOW_PRIVATE_IP_ADDRESS = "1";
    S3_ENDPOINT = "http://localhost:9000";
    S3_BUCKET = "lobe";
    S3_ENABLE_PATH_STYLE = "1";
    S3_SET_ACL = "0";
  };
in
{
  sops.secrets = {
    "api-keys/omniroute/lobehub" = { };
    "api-keys/github-mcp" = { };
    "lobehub/postgres-password" = { };
    "lobehub/auth-secret" = { };
    "lobehub/key-vaults-secret" = { };
    "lobehub/s3-access-key" = { };
    "lobehub/s3-secret-key" = { };
  };

  sops.templates."lobehub.env".content = ''
    OPENAI_API_KEY=${config.sops.placeholder."api-keys/omniroute/lobehub"}
    DATABASE_URL=postgres://lobehub:${
      config.sops.placeholder."lobehub/postgres-password"
    }@127.0.0.1:${toString pgPort}/postgres
    AUTH_SECRET=${config.sops.placeholder."lobehub/auth-secret"}
    KEY_VAULTS_SECRET=${config.sops.placeholder."lobehub/key-vaults-secret"}
    S3_ACCESS_KEY_ID=${config.sops.placeholder."lobehub/s3-access-key"}
    S3_SECRET_ACCESS_KEY=${config.sops.placeholder."lobehub/s3-secret-key"}
  '';

  sops.templates."lobehub-postgres.env".content = ''
    POSTGRES_USER=lobehub
    POSTGRES_PASSWORD=${config.sops.placeholder."lobehub/postgres-password"}
    POSTGRES_DB=postgres
    TELEMETRY=false

  '';

  sops.templates."lobehub-github.env".content = ''
    GITHUB_PERSONAL_ACCESS_TOKEN=${config.sops.placeholder."api-keys/github-mcp"}
  '';

  systemd.user.services = lib.mapAttrs' mkMcpService mcpServers // {
    lobehub-postgres = {
      Unit = {
        Description = "ParadeDB (Postgres + pgvector + pg_search) for LobeHub";
        After = [
          "network.target"
          "sops-nix.service"
        ];
      };
      Service = {
        Environment = [ "PATH=${podmanPath}" ];
        ExecStart = lib.concatStringsSep " " [
          podman
          "run --rm --replace --name lobehub-postgres --network=host"
          "--env-file ${config.sops.templates."lobehub-postgres.env".path}"
          "-v lobehub-paradedb:/var/lib/postgresql/data"
          pgImage
          "postgres -c listen_addresses=127.0.0.1 -c port=${toString pgPort}"
        ];
        ExecStop = "${podman} stop -t 30 lobehub-postgres";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 900;
      };
      Install.WantedBy = [ "default.target" ];
    };

    lobehub-redis = {
      Unit.Description = "Valkey for LobeHub";
      Service = {
        ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p ${redisDir}";
        ExecStart = "${lib.getExe' pkgs.valkey "valkey-server"} --bind 127.0.0.1 --port ${toString redisPort} --dir ${redisDir}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    lobehub = {
      Unit = {
        Description = "LobeHub (container)";
        After = [
          "network.target"
          "sops-nix.service"
          "lobehub-postgres.service"
          "lobehub-redis.service"
        ];
        Requires = [
          "lobehub-postgres.service"
          "lobehub-redis.service"
        ];
      };
      Service = {
        Environment = [ "PATH=${podmanPath}" ];
        ExecStartPre = waitPostgres;
        ExecStart = lib.concatStringsSep " " (
          [
            podman
            "run --rm --replace --name lobehub --network=host"
            "--env-file ${config.sops.templates."lobehub.env".path}"
          ]
          ++ lib.mapAttrsToList (k: v: "-e ${k}=${v}") containerEnv
          ++ [ appImage ]
        );
        ExecStop = "${podman} stop -t 10 lobehub";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 900;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
