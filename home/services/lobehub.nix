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

  waitPostgres = pkgs.writeShellScript "lobehub-wait-postgres" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
      ${pkgs.postgresql_17}/bin/pg_isready -q -h 127.0.0.1 -p ${toString pgPort} && exit 0
      ${pkgs.coreutils}/bin/sleep 1
    done
    exit 1
  '';

  mcpUrls = pkgs.writeShellScriptBin "lobehub-mcp-urls" ''
    cat <<'EOF'
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: url: "${name}  ${url}") config.my.mcp.endpoints
    )}
    EOF
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
    AUTH_SSO_PROVIDERS = "github";
  };
in
{
  home.packages = [ mcpUrls ];

  sops.secrets = {
    "api-keys/omniroute/lobehub" = { };
    "lobehub/postgres-password" = { };
    "lobehub/auth-secret" = { };
    "lobehub/key-vaults-secret" = { };
    "lobehub/s3-access-key" = { };
    "lobehub/s3-secret-key" = { };
    "github-app/pludex-bot/id" = { };
    "github-app/pludex-bot/auth-key" = { };
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
    AUTH_GITHUB_ID=${config.sops.placeholder."github-app/pludex-bot/id"}
    AUTH_GITHUB_SECRET=${config.sops.placeholder."github-app/pludex-bot/auth-key"}
  '';

  sops.templates."lobehub-postgres.env".content = ''
    POSTGRES_USER=lobehub
    POSTGRES_PASSWORD=${config.sops.placeholder."lobehub/postgres-password"}
    POSTGRES_DB=postgres
    TELEMETRY=false

  '';

  systemd.user.services = {
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
