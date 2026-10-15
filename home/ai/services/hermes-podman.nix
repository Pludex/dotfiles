{
  config,
  lib,
  pkgs,
  ...
}:
let
  omnirouteKey = config.sops.placeholder."api-keys/omniroute/hermes";
  omniroute = config.ai.omniroute;
  hermesHome = "/workspaces/hermes";

  syncBody = pkgs.writeShellScript "hermes-git-sync-body" ''
    set -euo pipefail
    cd ${hermesHome}

    if [ ! -f .gitignore ]; then
      cat > .gitignore << 'EOF'
    /*
    !/.gitignore
    !/SOUL.md
    !/memories/
    !/skills/
    !/hooks/
    !/plugins/

    *.db
    *.db-*
    *.sqlite*
    *.lock
    *.log
    __pycache__/
    *.pyc
    .env
    *.env
    EOF
    fi

    git add -A
    git diff --cached --quiet && exit 0
    git commit -m "sync $(date -Is)"
    git push -u origin main
  '';
in
{
  imports = [
    ../modules/hermes-podman.nix
  ];

  sops.secrets."api-keys/omniroute/hermes" = { };
  sops.secrets."api-keys/hermes/api-server" = { };
  sops.secrets."ssh/hermes-deploy" = { };

  sops.templates."hermes-env".content = ''
    OPENAI_API_KEY=${omnirouteKey}
    OMNIROUTE_API_KEY=${omnirouteKey}
    API_SERVER_KEY=${config.sops.placeholder."api-keys/hermes/api-server"}
  '';

  services.hermes-podman = {
    enable = true;
    inherit hermesHome;
    gateway.enable = true;
    restart = "on-failure";

    settings = {
      model = {
        provider = "custom:omniroute";
        default = "auto";
        base_url = "";
      };

      providers.omniroute = {
        api = "${omniroute.url-base}/v1";
        api_key = "\${OMNIROUTE_API_KEY}";
        transport = "openai_chat";
        discover_models = false;
        models = [ "auto" ];
      };

      mcp_servers.omniroute = {
        url = "${omniroute.url-base}/api/mcp/stream";
        headers.Authorization = "Bearer \${OMNIROUTE_API_KEY}";
      };
    };
    substituteVars = [ "OMNIROUTE_API_KEY" ];

    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = "8642";
    };
    environmentFiles = [ config.sops.templates."hermes-env".path ];

    podman = {
      extraArgs = [ "--shm-size=1g" ];
      after = [
        "sops-nix.service"
        "podman-omniroute.service"
      ];
      wants = [
        "sops-nix.service"
        "omniroute-bootstrap.service"
      ];
      stopTimeout = 40;
    };
  };

  sops.templates."hermes-git-sync-env".content = ''
    GIT_SSH_COMMAND="ssh -F /dev/null -i ${
      config.sops.secrets."ssh/hermes-deploy".path
    } -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    GIT_AUTHOR_NAME=hermes-sync
    GIT_AUTHOR_EMAIL=hermes-sync@localhost
    GIT_COMMITTER_NAME=hermes-sync
    GIT_COMMITTER_EMAIL=hermes-sync@localhost
  '';

  systemd.user.services.hermes-git-sync = {
    Unit.Description = "Commit and push Hermes data";
    Service = {
      Type = "oneshot";
      ExecStart = "${syncBody}";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.git
            pkgs.openssh
            pkgs.coreutils
          ]
        }:/run/wrappers/bin"
      ];
      EnvironmentFile = [ config.sops.templates."hermes-git-sync-env".path ];
    };
  };

  systemd.user.timers.hermes-git-sync = {
    Unit.Description = "Periodic Hermes data sync";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
