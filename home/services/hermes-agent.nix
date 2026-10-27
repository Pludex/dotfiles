{
  config,
  lib,
  pkgs,
  base,
  inputs,
  ...
}:
let
  inherit (base) myPkgs;
  hermes-agent = base.app "hermes-agent";
  omniroute = base.app "omniroute";
  hermesHome = "/app/data";
  inherit (config) app;

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

  omhPkg = myPkgs.oh-my-hermes;
  omhHome = "${hermesHome}/omh";

  # Combos that the routing chains below refer to. Used only as:
  #   1. fallback when omniroute /v1/models is unreachable
  #   2. sanity check (warn if a chain target is missing from the live list)
  combos = [
    "chat-fast"
    "code-std"
    "code-pro"
    "agent-pro"
  ];
  chain = model: effort: [
    {
      inherit model;
      reasoning_effort = effort;
    }
  ];

  chainsFile = pkgs.writeText "model-chains.json" (
    builtins.toJSON {
      schema_version = "mixture_chain_overrides/v1";
      categories = {
        quick = chain "chat-fast" "low";
        visual-engineering = chain "code-std" "medium";
        deep = chain "code-pro" "high";
        ultrabrain = chain "agent-pro" "high";
      };
    }
  );

  # Static fallback, only used when /v1/models cannot be fetched
  # and no previous model-providers.json exists yet.
  routesFile = pkgs.writeText "model-providers.json" (
    builtins.toJSON {
      schema_version = "model_provider_routes/v1";
      models = lib.genAttrs combos (model: {
        provider = "custom:omniroute";
        inherit model;
      });
    }
  );

  omhSync = pkgs.writeShellScript "omh-sync" ''
    set -euo pipefail
    export HERMES_HOME=${hermesHome} OMH_HOME=${omhHome}
    mkdir -p "$OMH_HOME/routing"

    if [ "$(cat "$OMH_HOME/.nix-store-path" 2>/dev/null || true)" != "${omhPkg}" ]; then
      omh setup --no-interactive --json
      printf '%s' "${omhPkg}" > "$OMH_HOME/.nix-store-path"
    fi

    install -m 0644 ${chainsFile} "$OMH_HOME/routing/model-chains.json"

    # model-providers.json: generated from omniroute's /v1/models at runtime.
    # To only expose combos, add a select(...) before map(...) in the jq filter
    # (check `curl .../v1/models | jq` for a field such as owned_by).
    dst="$OMH_HOME/routing/model-providers.json"
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT

    if curl -fsS --max-time 10 \
         -H "Authorization: Bearer $OMNIROUTE_API_KEY" \
         "${omniroute.urlBase}/v1/models" \
       | jq '{
           schema_version: "model_provider_routes/v1",
           models: (
             .data
             | map({
                 key: .id,
                 value: { provider: "custom:omniroute", model: .id }
               })
             | from_entries
           )
         }' > "$tmp" \
       && [ "$(jq '.models | length' "$tmp")" -gt 0 ]; then
      install -m 0644 "$tmp" "$dst"

      # warn when a model referenced by model-chains.json is not served
      jq -r --argjson want '${builtins.toJSON combos}' \
        '($want - (.models | keys))[]' "$dst" \
        | while read -r m; do
            echo "warning: chain model '$m' not found in omniroute /v1/models" >&2
          done
    else
      echo "omniroute /v1/models unavailable, keeping existing routes or using fallback" >&2
      [ -f "$dst" ] || install -m 0644 ${routesFile} "$dst"
    fi
  '';

  hermesPkg = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    version = "0.22.5";
  };
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
    package = hermesPkg;
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

      plugins.entries.omh.settings.omh_home = omhHome;
      skills.external_dirs = [ "${omhHome}/skills" ];
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
      API_SERVER_PORT = toString hermes-agent.port;
      OMH_HOME = omhHome;
    };

    environmentFiles = [ (templatePath "hermes-env") ];
  };

  systemd.user.services.hermes-agent.Unit = {
    After = [
      "sops-nix.service"
      "podman-omniroute.service"
      "hermes-env-merge.service"
      "omh-sync.service"
    ];
    Wants = [
      "sops-nix.service"
      "omniroute-bootstrap.service"
      "hermes-env-merge.service"
      "omh-sync.service"
    ];
  };

  programs.hermes-agent = {
    enable = true;
    package = hermesPkg;
    desktop.enable = false;
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
    XDG_RUNTIME_DIR = "/run/user/${toString app.uid}";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString app.uid}/bus";
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

  home.packages = [ omhPkg ];

  systemd.user.services.omh-sync = {
    Unit = {
      Description = "Sync oh-my-hermes into the hermes home";
      After = [
        "sops-nix.service"
        "podman-omniroute.service"
        "omniroute-bootstrap.service"
        "hermes-env-merge.service"
      ];
      Wants = [
        "sops-nix.service"
        "hermes-env-merge.service"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${omhSync}";
      # provides OMNIROUTE_API_KEY for the /v1/models request
      EnvironmentFile = [ (templatePath "hermes-env") ];
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
            omhPkg
          ]
        }:${config.home.profileDirectory}/bin"
      ];
    };
  };

  # Refresh the model list periodically so new omniroute combos show up
  # without a rebuild.
  systemd.user.timers.omh-sync = {
    Unit.Description = "Periodic oh-my-hermes / omniroute model sync";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
