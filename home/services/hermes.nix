{
  config,
  lib,
  pkgs,
  base,
  inputs,
  ...
}:
let
  hermes = base.appOf "hermes-agent";
  omniroute = base.appOf "omniroute";
  hermesHome = "/app/data";
  inherit (config) bot;

  ph = config.sops.placeholder;
  secretPath = name: config.sops.secrets.${name}.path;
  templatePath = name: config.sops.templates.${name}.path;

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

  mergeEnv = pkgs.writeShellScript "hermes-merge-env" ''
    set -euo pipefail
    src=${templatePath "hermes-env"}
    dst=${hermesHome}/.env

    touch "$dst"
    keys=$(cut -d= -f1 "$src" | paste -sd'|')
    tmp=$(mktemp)

    # keep unrelated lines, replace the sops-managed ones
    grep -vE "^($keys)=" "$dst" > "$tmp" || true
    cat "$src" >> "$tmp"
    install -m 600 "$tmp" "$dst"
    rm -f "$tmp"
  '';
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
  ];

  sops = {
    secrets = lib.genAttrs [
      "api-keys/omniroute/main"
      "api-keys/omniroute/manage"
      "api-keys/api-server"
      "api-keys/context7"
      "github/mcp-token"
      "ssh/deploy"
      "desktop-token"
    ] (_: { });

    templates."hermes-env".content = ''
      OPENAI_API_KEY=${ph."api-keys/omniroute/main"}
      OMNIROUTE_API_KEY=${ph."api-keys/omniroute/main"}
      API_SERVER_KEY=${ph."api-keys/api-server"}
      CONTEXT7_API_KEY=${ph."api-keys/context7"}
      GITHUB_MCP_TOKEN=${ph."github/mcp-token"}
      OMNIROUTE_MANAGE_KEY=${ph."api-keys/omniroute/manage"}
    '';

    templates."hermes-git-sync-env".content = ''
      GIT_SSH_COMMAND="ssh -F /dev/null -i ${secretPath "ssh/deploy"} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
      GIT_AUTHOR_NAME=hermes-sync
      GIT_AUTHOR_EMAIL=hermes-sync@localhost
      GIT_COMMITTER_NAME=hermes-sync
      GIT_COMMITTER_EMAIL=hermes-sync@localhost
    '';
  };

  services.hermes-agent = {
    enable = true;
    inherit hermesHome;
    gateway.enable = true;
    restart = "on-failure";

    backend = {
      mode = "dashboard";
      sessionTokenFile = secretPath "desktop-token";
    };

    settings = {
      model = {
        provider = "custom:omniroute";
        default = "gemini";
        base_url = "${omniroute.urlBase}/v1";
      };

      providers.omniroute = {
        api = "${omniroute.urlBase}/v1";
        api_key = "\${OMNIROUTE_API_KEY}";
        transport = "openai_chat";
        discover_models = true;
      };
    };

    mcpServers = {
      omniroute = {
        url = "${omniroute.urlBase}/api/mcp/stream";
        headers.Authorization = "Bearer \${OMNIROUTE_API_KEY}";
      };
      context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "\${CONTEXT7_API_KEY}";
      };
      github = {
        url = "https://api.githubcopilot.com/mcp/";
        headers.Authorization = "Bearer \${GITHUB_MCP_TOKEN}";
      };
    };

    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = toString hermes.port;
    };
    environmentFiles = [ (templatePath "hermes-env") ];
  };

  systemd.user.services.hermes-agent.Unit = {
    After = [
      "sops-nix.service"
      "podman-omniroute.service"
      "hermes-env-merge.service"
    ];
    Wants = [
      "sops-nix.service"
      "omniroute-bootstrap.service"
      "hermes-env-merge.service"
    ];
  };

  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };

  systemd.user.services.hermes-git-sync = {
    Unit = {
      Description = "Commit and push Hermes data";
      After = [ "sops-nix.service" ];
      Wants = [ "sops-nix.service" ];
    };
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
      EnvironmentFile = [ (templatePath "hermes-git-sync-env") ];
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

  systemd.user.services.hermes-agent.Service.EnvironmentFile = [
    (templatePath "hermes-env")
  ];

  systemd.user.services.hermes-backend = {
    Unit = {
      After = [ "sops-nix.service" ];
      Wants = [ "sops-nix.service" ];
    };
    Service.EnvironmentFile = [ (templatePath "hermes-env") ];
  };

  home.sessionVariables = {
    XDG_RUNTIME_DIR = "/run/user/${toString bot.uid}";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString bot.uid}/bus";
  };

  systemd.user.services.hermes-env-merge = {
    Unit = {
      Description = "Merge sops-rendered secrets into Hermes .env";
      After = [ "sops-nix.service" ];
      Wants = [ "sops-nix.service" ];
      Before = [
        "hermes-agent.service"
        "hermes-backend.service"
      ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${mergeEnv}";
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
          ]
        }"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
