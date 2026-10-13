# SPDX-License-Identifier: MIT
#
# Copyright (c) Nous Research and hermes-agent contributors
#   Original work: nix/moduleCommon.nix and nix/homeManagerModules.nix
#   https://github.com/NousResearch/hermes-agent
#
# Copyright (c) 2026 <YOUR NAME>
#   Modifications: the two upstream files are merged into one Home Manager
#   module, the podman variant only. The option roots are renamed from
#   `services.hermes-agent` / `programs.hermes-agent` to
#   `services.hermes-podman` / `programs.hermes-podman`, so the module does
#   not clash with the upstream options (for example on a future Darwin host).
#   Several defects of the originals are fixed. See AGENTS.md ("Changes from
#   upstream").
#
# NOTE: confirm the licence against the LICENSE file of the upstream
# repository and keep this header in sync with it.
#
# ─────────────────────────────────────────────────────────────────────────────
# hermes-podman — Hermes Agent in rootless Podman containers, for Home Manager.
#
# Wiring (flake):
#
#   homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
#     inherit pkgs;
#     extraSpecialArgs = { inherit inputs; };   # only needed for the default `package`
#     modules = [ ./hermes-podman.nix ./home.nix ];
#   };
#
#   # home.nix
#   programs.hermes-podman.enable = true;
#   services.hermes-podman = {
#     enable = true;
#     gateway.enable = true;
#     settings.model.default = "anthropic/claude-sonnet-4";
#     environmentFiles = [ config.sops.secrets."hermes/env".path ];
#   };
#
# If `inputs` is not available, set `services.hermes-podman.configVersion`
# (no package needed), or set `services.hermes-podman.package` yourself.
#
# CAUTION: enable linger for the account, or the user manager (and both
# containers) stop at logout. On NixOS: users.users.<name>.linger = true;
# elsewhere: loginctl enable-linger <name>
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  pkgs,
  ...
}@args:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.services.hermes-podman;
  cfgPrograms = config.programs.hermes-podman;
  pcfg = cfg.podman;

  podman = config.services.podman.package;

  # Where HERMES_HOME is mounted inside the container.
  dataDir = "/opt/data";
  managedSystem = "home-manager";

  # ── Configuration type ──────────────────────────────────────────────────
  # More than one module can set `settings = { ... }`. recursiveUpdate joins
  # all of the definitions. Without it, only the last definition applies.
  deepConfigType = types.mkOptionType {
    name = "hermes-config-attrs";
    description = "Hermes YAML config (attrset), merged deeply via lib.recursiveUpdate.";
    check = builtins.isAttrs;
    merge = _loc: defs: lib.foldl' lib.recursiveUpdate { } (map (d: d.value) defs);
  };

  documentsType = types.attrsOf (types.either types.str types.path);

  # ── MCP server submodule ────────────────────────────────────────────────
  mcpServerType = types.submodule {
    options = {
      # Stdio transport
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MCP server command (stdio transport).";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Command-line arguments (stdio transport).";
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for the server process (stdio transport).";
      };

      # HTTP/StreamableHTTP transport
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MCP server endpoint URL (HTTP/StreamableHTTP transport).";
      };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "HTTP headers, e.g. for authentication (HTTP transport).";
      };

      auth = mkOption {
        type = types.nullOr (types.enum [ "oauth" ]);
        default = null;
        description = ''
          Authentication method. Set to "oauth" for OAuth 2.1 PKCE flow
          (remote MCP servers). Tokens are stored in $HERMES_HOME/mcp-tokens/.
        '';
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable or disable this MCP server.";
      };

      timeout = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Tool call timeout in seconds (default: 120).";
      };
      connect_timeout = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Initial connection timeout in seconds (default: 60).";
      };

      tools = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              include = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Tool allowlist — only these tools are registered.";
              };
              exclude = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Tool blocklist — these tools are hidden.";
              };
            };
          }
        );
        default = null;
        description = "Filter which tools are exposed by this server.";
      };

      sampling = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              enabled = mkOption {
                type = types.bool;
                default = true;
                description = "Enable sampling.";
              };
              model = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Override model for sampling requests.";
              };
              max_tokens_cap = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Max tokens per request.";
              };
              timeout = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "LLM call timeout in seconds.";
              };
              max_rpm = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Max requests per minute.";
              };
              max_tool_rounds = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Max tool-use rounds per sampling request.";
              };
              allowed_models = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Models the server is allowed to request.";
              };
              log_level = mkOption {
                type = types.nullOr (
                  types.enum [
                    "debug"
                    "info"
                    "warning"
                  ]
                );
                default = null;
                description = "Audit log level for sampling requests.";
              };
            };
          }
        );
        default = null;
        description = "Sampling configuration for server-initiated LLM requests.";
      };
    };
  };

  # Convert the mcpServers submodules into the shape that config.yaml uses.
  mcpServersToConfig =
    servers:
    lib.mapAttrs (
      _name: srv:
      lib.optionalAttrs (srv.command != null) { inherit (srv) command args; }
      // lib.optionalAttrs (srv.env != { }) { inherit (srv) env; }
      // lib.optionalAttrs (srv.url != null) { inherit (srv) url; }
      // lib.optionalAttrs (srv.headers != { }) { inherit (srv) headers; }
      // lib.optionalAttrs (srv.auth != null) { inherit (srv) auth; }
      // {
        inherit (srv) enabled;
      }
      // lib.optionalAttrs (srv.timeout != null) { inherit (srv) timeout; }
      // lib.optionalAttrs (srv.connect_timeout != null) { inherit (srv) connect_timeout; }
      // lib.optionalAttrs (srv.tools != null) {
        tools = lib.filterAttrs (_: v: v != [ ]) {
          inherit (srv.tools) include exclude;
        };
      }
      // lib.optionalAttrs (srv.sampling != null) {
        sampling = lib.filterAttrs (_: v: v != null && v != [ ]) {
          inherit (srv.sampling)
            enabled
            model
            max_tokens_cap
            timeout
            max_rpm
            max_tool_rounds
            allowed_models
            log_level
            ;
        };
      }
    ) servers;

  # ── Paths ───────────────────────────────────────────────────────────────
  # The workspace may live inside HERMES_HOME (already mounted) or outside it
  # (needs its own mount, at the same path).
  inHome = cfg.workingDirectory == cfg.hermesHome || lib.hasPrefix "${cfg.hermesHome}/" cfg.workingDirectory;

  # terminal.cwd must be the path the agent sees inside the container.
  containerWorkdir =
    if inHome then dataDir + lib.removePrefix cfg.hermesHome cfg.workingDirectory else cfg.workingDirectory;

  # ── Rendered config.yaml ────────────────────────────────────────────────
  # YAML contains JSON, so the output of toJSON is a valid config.yaml.
  # In managed mode Hermes refuses to write config.yaml, so it cannot stamp
  # `_config_version` itself and an unstamped file reads as version 0 at every
  # boot. The version comes from `configVersion`, or else from the package's
  # DEFAULT_CONFIG at build time.
  generatedConfig =
    if cfg.configVersion != null then
      pkgs.writeText "hermes-config.json" (
        builtins.toJSON (
          lib.recursiveUpdate {
            _config_version = cfg.configVersion;
            terminal.cwd = containerWorkdir;
          } cfg.settings
        )
      )
    else
      pkgs.runCommand "hermes-config.json"
        {
          settings = builtins.toJSON (lib.recursiveUpdate { terminal.cwd = containerWorkdir; } cfg.settings);
          passAsFile = [ "settings" ];
        }
        ''
          HOME=$TMPDIR ${cfg.package.hermesVenv}/bin/python3 - "$settingsPath" > $out <<'PY'
          import json, sys
          from hermes_cli.config_defaults import DEFAULT_CONFIG
          with open(sys.argv[1]) as f:
              settings = json.load(f)
          settings.setdefault("_config_version", DEFAULT_CONFIG["_config_version"])
          json.dump(settings, sys.stdout)
          PY
        '';

  # Deep-merge Nix settings into the config.yaml on disk. Nix keys override;
  # keys added at runtime (skills, streaming, …) are preserved.
  mergeScript = pkgs.writeScript "hermes-config-merge" ''
    #!${pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ])}/bin/python3
    import json, sys
    from pathlib import Path
    from ruamel.yaml import YAML

    yaml = YAML(typ="safe", pure=True)
    # Existing configs use YAML 1.1 booleans such as yes and off.
    yaml.version = (1, 1)
    yaml.default_flow_style = False
    yaml.sort_base_mapping_type_on_output = False

    nix_json, config_path = sys.argv[1], Path(sys.argv[2])

    with open(nix_json) as f:
        nix = json.load(f)

    existing = {}
    if config_path.exists():
        with open(config_path) as f:
            existing = yaml.load(f) or {}

    def deep_merge(base, override):
        result = dict(base)
        for k, v in override.items():
            if k in result and isinstance(result[k], dict) and isinstance(v, dict):
                result[k] = deep_merge(result[k], v)
            else:
                result[k] = v
        return result

    merged = deep_merge(existing, nix)

    # Write atomically, so a crash never leaves a half-written config.yaml.
    tmp = config_path.with_name(config_path.name + ".tmp")
    with open(tmp, "w") as f:
        yaml.dump(merged, f)
    tmp.replace(config_path)
  '';

  # ── Documents ───────────────────────────────────────────────────────────
  # Strings become store files (no heredoc, so no content can end the script
  # early); paths and store paths are copied as they are.
  mkTree =
    name: files:
    pkgs.runCommand name { } (
      ''
        mkdir -p "$out"
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          rel: value:
          let
            dir = builtins.dirOf rel;
            src =
              if builtins.isPath value || lib.isStorePath value then
                value
              else
                pkgs.writeText "hermes-doc" value;
          in
          lib.optionalString (dir != ".") "mkdir -p \"$out\"/${lib.escapeShellArg dir}\n"
          + "cp --no-preserve=mode ${src} \"$out\"/${lib.escapeShellArg rel}"
        ) files
      )
    );

  documentTree = mkTree "hermes-documents" cfg.documents;
  homeFilesTree = mkTree "hermes-home-files" cfg.hermesHomeFiles;

  installTree =
    tree: root: files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        rel: _:
        "install -m 0600 -D ${lib.escapeShellArg "${tree}/${rel}"} ${lib.escapeShellArg "${root}/${rel}"}"
      ) files
    );

  # ── .env ────────────────────────────────────────────────────────────────
  # Non-secret values come from the Nix store. Activation then appends the
  # secrets from runtime paths outside the store. The file is rewritten from
  # the start each time, so a second activation never duplicates secrets.
  envBase = pkgs.writeText "hermes-env-base" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment)
    + lib.optionalString (cfg.environment != { }) "\n"
  );

  envScript = pkgs.writeShellScript "hermes-env-merge" ''
    set -eu
    dest="$1"
    shift
    install -m 0600 ${envBase} "$dest"
    for file in "$@"; do
      if [ -r "$file" ]; then
        printf '\n' >> "$dest"
        cat "$file" >> "$dest"
      else
        echo "hermes-podman: WARNING cannot read environmentFile $file" >&2
      fi
    done
  '';

  # ── State setup ─────────────────────────────────────────────────────────
  # Runs inside `podman unshare`, so the files are owned by the user that the
  # container maps to the host user, and `:U` volumes can be re-chowned.
  home = lib.escapeShellArg cfg.hermesHome;

  stateScript = pkgs.writeShellScript "hermes-podman-state" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils ]}:$PATH

    # Directories, created here so the first activation sets the right mode.
    mkdir -p ${
      lib.escapeShellArgs (
        [
          cfg.hermesHome
          cfg.workingDirectory
        ]
        ++ map (d: "${cfg.hermesHome}/${d}") stateSubdirs
      )
    }

    # config.yaml: merge the Nix settings into the file on disk. Hermes writes
    # this file at runtime, so a read-only store symlink would break each save.
    ${
      if cfg.configFile != null then
        "install -m 0600 -D ${cfg.configFile} ${home}/config.yaml"
      else
        ''
          ${mergeScript} ${generatedConfig} ${home}/config.yaml
          chmod 0600 ${home}/config.yaml
        ''
    }

    # The managed-mode marker: an interactive shell also refuses to change the
    # configuration that Nix owns.
    install -m 0600 ${pkgs.writeText "hermes-managed" managedSystem} ${home}/.managed

    ${lib.optionalString (cfg.environment != { } || cfg.environmentFiles != [ ]) ''
      ${envScript} ${home}/.env ${lib.escapeShellArgs cfg.environmentFiles}
    ''}

    ${lib.optionalString (cfg.authFile != null) (
      if cfg.authFileForceOverwrite then
        ''
          install -m 0600 ${lib.escapeShellArg cfg.authFile} ${home}/auth.json
        ''
      else
        ''
          if [ ! -e ${home}/auth.json ]; then
            install -m 0600 ${lib.escapeShellArg cfg.authFile} ${home}/auth.json
          fi
        ''
    )}

    ${installTree documentTree cfg.workingDirectory cfg.documents}
    ${installTree homeFilesTree cfg.hermesHome cfg.hermesHomeFiles}

    # Declarative plugins. Old managed symlinks go first, so a plugin that you
    # remove from the configuration also leaves the plugins directory.
    find ${home}/plugins -maxdepth 1 -type l -name 'nix-managed-*' -delete 2>/dev/null || true
    ${lib.concatMapStringsSep "\n" (plugin: ''
      if [ ! -f ${plugin}/plugin.yaml ]; then
        echo "hermes-podman: ERROR extraPlugins entry '${plugin}' has no plugin.yaml" >&2
        exit 1
      fi
      ln -sfn ${plugin} ${home}/plugins/nix-managed-${lib.getName plugin}
    '') cfg.extraPlugins}
  '';

  stateSubdirs = [
    "cron"
    "sessions"
    "logs"
    "memories"
    "plugins"
  ];

  # ── Containers ──────────────────────────────────────────────────────────
  # The image entrypoint is already `hermes`, so these are its arguments.
  gatewayArgs = [ "gateway" ] ++ cfg.extraArgs;

  backendArgs = [
    cfg.backend.mode
    "--host"
    cfg.backend.host
    "--port"
    (toString cfg.backend.port)
    # A service must not try to open a browser when it starts.
    "--no-open"
  ]
  ++ cfg.backend.extraArgs;

  containerEnvironment = {
    HERMES_HOME = dataDir;
    HERMES_MANAGED = managedSystem;
  }
  // cfg.environment;

  mkContainer = args': {
    inherit (pcfg) image network;
    exec = lib.escapeShellArgs args';
    environment = containerEnvironment;
    environmentFile = cfg.environmentFiles;
    volumes = [
      "${cfg.hermesHome}:${dataDir}:U"
    ]
    ++ lib.optional (!inHome) "${cfg.workingDirectory}:${cfg.workingDirectory}:U"
    ++ lib.optional (cfg.extraPlugins != [ ]) "/nix/store:/nix/store:ro"
    ++ pcfg.extraVolumes;
    extraPodmanArgs = pcfg.extraArgs;
    extraConfig = {
      Unit = {
        After = pcfg.after;
        Wants = pcfg.wants;
      };
      Container.StopTimeout = pcfg.stopTimeout;
      Service = {
        Restart = lib.mkForce cfg.restart;
        RestartSec = lib.mkForce (toString cfg.restartSec);
      };
    };
  };

  # The CLI wrapper talks to the gateway container, or to the backend
  # container when only that one is enabled.
  cliTarget = if cfg.gateway.enable then pcfg.name else "${pcfg.name}-backend";

  cliWrapper = pkgs.writeShellScriptBin cfgPrograms.commandName ''
    flags=-i
    if [ -t 0 ] && [ -t 1 ]; then flags=-it; fi
    exec ${podman}/bin/podman exec $flags ${lib.escapeShellArg cliTarget} hermes "$@"
  '';

  badDocName = name: lib.hasPrefix "/" name || lib.elem ".." (lib.splitString "/" name);
in
{
  # ════════════════════════════════════════════════════════════════════════
  # Options
  # ════════════════════════════════════════════════════════════════════════
  options.programs.hermes-podman = {
    enable = mkEnableOption ''
      the Hermes CLI on PATH. It is a wrapper that runs `hermes` inside the
      Hermes container
    '';

    commandName = mkOption {
      type = types.str;
      default = "hermes";
      description = ''
        The name of the wrapper command. Change it when another `hermes`
        (for example the upstream package) is also on your PATH.
      '';
      example = "hermes-podman";
    };
  };

  options.services.hermes-podman = {
    enable = mkEnableOption "Hermes Agent in rootless Podman containers";

    package = mkOption {
      type = types.package;
      default =
        if args ? inputs then
          # args.inputs.hermes.packages.${pkgs.stdenv.hostPlatform.system}.default
          args.pkgs.hermes
        else
          throw "services.hermes-podman.package: no `inputs` in specialArgs. Pass `extraSpecialArgs = { inherit inputs; }`, set `package`, or set `configVersion`.";
      defaultText = literalExpression "inputs.self.packages.\${system}.default";
      description = ''
        The hermes-agent package. In podman mode the runtime is the container
        image, so this is used only at build time, to read `_config_version`
        for config.yaml. It is not evaluated when `configVersion` is set.
      '';
    };

    configVersion = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        The `_config_version` to stamp into config.yaml. When null, the value
        is read from the `package`. Set it to build config.yaml without the
        package. It must match the image that you run.
      '';
    };

    hermesHome = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.hermes";
      description = "Host directory mounted into the container as HERMES_HOME (/opt/data).";
      example = "/workspaces/hermes";
    };

    workingDirectory = mkOption {
      type = types.str;
      default = "${cfg.hermesHome}/workspace";
      defaultText = literalExpression ''"''${config.services.hermes-podman.hermesHome}/workspace"'';
      description = ''
        The working directory of the agent. The module also writes the path
        that the container sees to config.yaml as `terminal.cwd`. A directory
        outside hermesHome gets its own volume, mounted at the same path.
      '';
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        The path to an existing config.yaml. If you set this option, it
        replaces the `settings` option. The module installs the file without a
        change and overwrites all runtime edits on each activation.
      '';
    };

    settings = mkOption {
      type = deepConfigType;
      default = { };
      description = ''
        The Hermes configuration, as an attribute set. The module joins the
        definitions from all modules and writes the result to config.yaml.

        The merge into the config.yaml on disk is also a deep merge. These keys
        replace the keys on disk. The module keeps all other keys, which
        includes the keys that `hermes config set` and the settings panes of
        the TUI and the desktop app write at runtime.
      '';
      example = literalExpression ''
        {
          model.default = "anthropic/claude-sonnet-4";
          terminal.backend = "local";
          compression = { enabled = true; threshold = 0.85; };
        }
      '';
    };

    # ── Secrets / environment ───────────────────────────────────────────
    environmentFiles = mkOption {
      # `str` and not `path`: a Nix path literal copies the secret into the
      # Nix store, which all users can read.
      type = types.listOf types.str;
      default = [ ];
      description = ''
        The paths to environment files that contain secrets, for example API
        keys and tokens. They are read at runtime, added to $HERMES_HOME/.env,
        and also given to the containers with --env-file.

        Each activation writes .env again from the start, so a secret file
        cannot go into .env two times.
      '';
      example = literalExpression ''[ config.sops.secrets."hermes/env".path ]'';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Environment variables that are not secret. Activation writes them to
        $HERMES_HOME/.env, and the containers receive them.

        CAUTION: Do not put secrets in this option. All users can read the Nix
        store. Use environmentFiles for secrets.
      '';
    };

    authFile = mkOption {
      # `str` and not `path`: auth.json holds OAuth credentials.
      type = types.nullOr types.str;
      default = null;
      description = ''
        A runtime path to a file that gives the first contents of auth.json,
        the OAuth credentials. The module copies the file only when auth.json
        does not exist, so a token that Hermes refreshes stays after an
        activation. Use a path from sops-nix or agenix, never a Nix path
        literal.
      '';
      example = literalExpression ''config.sops.secrets."hermes/auth".path'';
    };

    authFileForceOverwrite = mkOption {
      type = types.bool;
      default = false;
      description = "Always overwrite auth.json from authFile on activation.";
    };

    # ── Documents ───────────────────────────────────────────────────────
    documents = mkOption {
      type = documentsType;
      default = { };
      description = ''
        Workspace files. The module installs them into workingDirectory. Each
        key is a relative path (subdirectories are created), and each value is
        a string or a path.

        Use this for the project context that the agent reads from its working
        directory, for example AGENTS.md, notes and checklists. Hermes reads
        SOUL.md and memories/ from HERMES_HOME, so put those in
        `hermesHomeFiles`.
      '';
      example = literalExpression ''
        {
          "AGENTS.md" = ./AGENTS.md;
          "notes/oncall.md" = "Page #infra before restarting anything.";
        }
      '';
    };

    hermesHomeFiles = mkOption {
      type = documentsType;
      default = { };
      description = ''
        Files that the module installs into HERMES_HOME. Each key is a relative
        path, and each value is a string or a path.

        Hermes reads SOUL.md and the memory files from HERMES_HOME and not from
        the working directory. Declare those files here, or Hermes does not
        load them.
      '';
      example = literalExpression ''
        {
          "SOUL.md" = "You are a helpful AI assistant.";
          "memories/USER.md" = ./USER.md;
        }
      '';
    };

    # ── MCP servers ─────────────────────────────────────────────────────
    mcpServers = mkOption {
      type = types.attrsOf mcpServerType;
      default = { };
      description = ''
        MCP server configurations (merged into settings.mcp_servers). Each
        server uses either stdio (command/args) or HTTP (url) transport.
        A stdio server runs inside the container, so its command must exist in
        the image.
      '';
      example = literalExpression ''
        {
          filesystem = {
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "/opt/data" ];
          };
          remote-oauth = {
            url = "https://mcp.example.com/mcp";
            auth = "oauth";
          };
        }
      '';
    };

    extraPlugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Directory-based plugin packages to symlink into the hermes plugins
        directory. Each package must contain a plugin.yaml and __init__.py at
        its root. The host /nix/store is mounted read-only into the containers
        so the symlinks resolve.
      '';
      example = literalExpression ''
        [
          (pkgs.fetchFromGitHub {
            owner = "stephenschoettler";
            repo = "hermes-lcm";
            name = "hermes-lcm";
            rev = "v0.7.0";
            hash = "sha256-...";
          })
        ]
      '';
    };

    # ── Service behaviour ───────────────────────────────────────────────
    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra command-line arguments for `hermes gateway`.";
    };

    restart = mkOption {
      type = types.str;
      default = "always";
      description = "The systemd Restart= policy of the container units.";
    };

    restartSec = mkOption {
      type = types.int;
      default = 5;
      description = "The systemd RestartSec= value of the container units.";
    };

    gateway.enable = mkEnableOption "the messaging gateway container";

    # `hermes serve` and `hermes dashboard` are one entry point with one flag
    # of difference; you can run only one of them, so this is an enum.
    backend = {
      mode = mkOption {
        type = types.enum [
          "none"
          "serve"
          "dashboard"
        ];
        default = "none";
        description = ''
          The backend container to run.

          - "none"      — no backend
          - "serve"     — the backend without a user interface. It gives the
                          /api/ws and /api/pty sockets that Hermes Desktop
                          connects to.
          - "dashboard" — all that "serve" gives, and the browser admin panel
                          on the same port
        '';
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          The address that the backend binds to. The container uses the host
          network by default.

          An address other than loopback starts the authentication gate of the
          dashboard. Configure credentials then, or a client cannot connect.
          The server also refuses each request with a Host header that differs
          from the bound address (a defence against DNS rebinding).
        '';
      };

      port = mkOption {
        type = types.port;
        default = 9119;
        description = "The port for the backend.";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "More command-line arguments for the backend command.";
      };
    };

    podman = {
      name = mkOption {
        type = types.str;
        default = "hermes-podman";
        description = "Container name. The backend container is named `<name>-backend`.";
      };
      image = mkOption {
        type = types.str;
        default = "docker.io/nousresearch/hermes-agent:latest";
        description = ''
          OCI image to run. Pin a tag that matches your `package` or
          `configVersion`, or `_config_version` can drift from the image.
        '';
      };
      network = mkOption {
        type = types.str;
        default = "host";
        description = "Podman network mode.";
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments passed to `podman run`.";
      };
      extraVolumes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra volume mounts in podman `src:dst[:opts]` format.";
      };
      after = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Systemd units the container service is ordered after.";
      };
      wants = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Systemd units the container service wants.";
      };
      stopTimeout = mkOption {
        type = types.int;
        default = 30;
        description = "Seconds to wait for the container to stop before killing it.";
      };
    };
  };

  # ════════════════════════════════════════════════════════════════════════
  # Config
  # ════════════════════════════════════════════════════════════════════════
  config = mkMerge [
    (mkIf cfgPrograms.enable {
      home.packages = [ cliWrapper ];

      warnings = lib.optional (
        !cfg.enable
      ) "programs.hermes-podman.enable is set, but services.hermes-podman.enable is not. The `${cfgPrograms.commandName}` wrapper has no container to talk to.";
    })

    (mkIf cfg.enable (mkMerge [
      (mkIf (cfg.mcpServers != { }) {
        services.hermes-podman.settings.mcp_servers = mcpServersToConfig cfg.mcpServers;
      })

      {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isLinux;
            message = "services.hermes-podman supports Linux only (rootless Podman with systemd user units).";
          }
          {
            # Two plugins with the same name use one nix-managed-<name>
            # symlink, and one of them would vanish without a message.
            assertion = lib.length (map lib.getName cfg.extraPlugins) == lib.length (lib.unique (map lib.getName cfg.extraPlugins));
            message = "services.hermes-podman.extraPlugins: duplicate plugin names: ${toString (map lib.getName cfg.extraPlugins)}. With fetchFromGitHub, set name = \"plugin-name\".";
          }
          {
            assertion = !(lib.any badDocName (lib.attrNames cfg.documents ++ lib.attrNames cfg.hermesHomeFiles));
            message = "services.hermes-podman.documents / hermesHomeFiles: a key must be a relative path without `..`.";
          }
        ];

        warnings =
          lib.optional (cfg.backend.mode == "none" && !cfg.gateway.enable)
            "services.hermes-podman is enabled, but neither gateway.enable nor backend.mode starts a container.";

        services.podman.enable = true;

        # Rootless: run inside the user namespace so that files in hermesHome
        # (re-owned by `:U` volumes) stay writable. newuidmap/newgidmap must
        # be on PATH: /run/wrappers/bin on NixOS, /usr/bin elsewhere.
        home.activation.hermesPodmanSetup = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
          run env PATH="/run/wrappers/bin:$PATH:/usr/bin" ${podman}/bin/podman unshare ${stateScript}
        '';
      }

      (mkIf cfg.gateway.enable {
        services.podman.containers.${pcfg.name} = mkContainer gatewayArgs;
      })

      (mkIf (cfg.backend.mode != "none") {
        services.podman.containers."${pcfg.name}-backend" = mkContainer backendArgs;
      })
    ]))
  ];
}
