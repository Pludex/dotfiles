{
  config,
  lib,
  pkgs,
  ...
}:
let
  omnirouteKey = config.sops.placeholder."api-keys/omniroute/hermes";
  omniroute = config.ai.omniroute;
  podman = config.services.podman.package;
  hermesHome = "/workspaces/hermes";

  # Runs inside `podman unshare` so files owned by the container's subuids are readable.
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
  sops.secrets."api-keys/omniroute/hermes" = { };
  sops.secrets."api-keys/hermes/api-server" = { };
  sops.secrets."ssh/hermes-deploy" = { };

  sops.templates."hermes-env".content = ''
    OPENAI_API_KEY=${omnirouteKey}
    OMNIROUTE_API_KEY=${omnirouteKey}
    API_SERVER_KEY=${config.sops.placeholder."api-keys/hermes/api-server"}
  '';

  programs.hermes-podman.enable = true;

  services.hermes-podman = {
    enable = true;
    inherit hermesHome;
    gateway.enable = true;
    restart = "on-failure";
    extraArgs = [ "run" ];

    settings = {
      model = {
        base_url = "${omniroute.url-base}/v1";
        default = "antigravity/gemini-3.1-flash-lite";
      };
      mcp_servers.omniroute = {
        url = "${omniroute.url-base}/api/mcp/stream";
        headers.Authorization = "Bearer \${OMNIROUTE_API_KEY}";
      };
    };

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
    GIT_SSH_COMMAND="ssh -F /dev/null -i ${config.sops.secrets."ssh/hermes-deploy".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    GIT_AUTHOR_NAME=hermes-sync
    GIT_AUTHOR_EMAIL=hermes-sync@localhost
    GIT_COMMITTER_NAME=hermes-sync
    GIT_COMMITTER_EMAIL=hermes-sync@localhost
  '';

  systemd.user.services.hermes-git-sync = {
    Unit.Description = "Commit and push Hermes data";
    Service = {
      Type = "oneshot";
      ExecStart = "${podman}/bin/podman unshare ${syncBody}";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            podman
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

  programs.git.settings.safe.directory = [
    hermesHome
  ];

  imports = [
    ../modules/hermes-podman.nix
  ];
}
