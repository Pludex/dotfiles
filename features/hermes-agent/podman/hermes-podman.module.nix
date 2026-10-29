# SPDX-License-Identifier: MIT
#
# Copyright (c) Nous Research and hermes-agent contributors
#   Original work: nix/moduleCommon.nix and nix/homeManagerModules.nix
#   https://github.com/NousResearch/hermes-agent
#
# Copyright (c) 2026 <YOUR NAME>
#   Modifications: merged into one Home Manager module (podman variant only),
#   option roots renamed to `services.hermes-podman` / `programs.hermes-podman`,
#   keep-id permission model, locked state setup, wrapped CLI/TUI/desktop/web.
#
# NOTE: confirm the licence against the LICENSE file of the upstream
# repository and keep this header in sync with it.
#
# Usage:
#
#   programs.hermes-podman = {
#     desktop.enable = true;
#     web.enable = true;
#   };
#   services.hermes-podman = {
#     enable = true;
#     gateway.enable = true;
#     hermesHome = "/workspaces/hermes";
#     environmentFiles = [ config.sops.secrets."hermes/env".path ];
#     settings.model.default = "anthropic/claude-sonnet-4";
#   };
#
# Enable linger for the account, or the user manager (and the containers)
# stop at logout: `loginctl enable-linger <name>`.

{
  config,
  lib,
  pkgs,
  ...
}:

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
  pgm = config.programs.hermes-podman;
  pcfg = cfg.podman;

  podman = config.services.podman.package;

  dataDir = "/opt/data";
  managedSystem = "home-manager";

  keepId = pcfg.permissions.mode == "keep-id";

  gatewayName = "${pcfg.namePrefix}-gateway";
  backendName = "${pcfg.namePrefix}-backend";

  deepConfigType = types.mkOptionType {
    name = "hermes-config-attrs";
    description = "Hermes YAML config (attrset), merged deeply via lib.recursiveUpdate.";
    check = builtins.isAttrs;
    merge = _loc: defs: lib.foldl' lib.recursiveUpdate { } (map (d: d.value) defs);
  };

  documentsType = types.attrsOf (types.either types.str types.path);

  mcpServerType = types.submodule {
    options = {
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
                description = "Tool allowlist: only these tools are registered.";
              };
              exclude = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Tool blocklist: these tools are hidden.";
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
  inHome =
    cfg.workingDirectory == cfg.hermesHome || lib.hasPrefix "${cfg.hermesHome}/" cfg.workingDirectory;

  containerWorkdir =
    if inHome then
      dataDir + lib.removePrefix cfg.hermesHome cfg.workingDirectory
    else
      cfg.workingDirectory;

  home = lib.escapeShellArg cfg.hermesHome;

  # ── Rendered config.yaml ────────────────────────────────────────────────
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

  mergeScript = pkgs.writeScript "hermes-config-merge" ''
    #!${pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ])}/bin/python3
    import json, sys
    from pathlib import Path
    from ruamel.yaml import YAML

    yaml = YAML(typ="safe", pure=True)
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

    tmp = config_path.with_name(config_path.name + ".tmp")
    with open(tmp, "w") as f:
        yaml.dump(merged, f)
    tmp.replace(config_path)
  '';

  # ── Documents ───────────────────────────────────────────────────────────
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
              if builtins.isPath value || lib.isStorePath value then value else pkgs.writeText "hermes-doc" value;
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
  stateSubdirs = [
    "cron"
    "sessions"
    "logs"
    "memories"
    "plugins"
  ];

  stateScriptInner = pkgs.writeShellScript "hermes-podman-state-inner" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnused
      ]
    }:$PATH

    mkdir -p ${
      lib.escapeShellArgs (
        [
          cfg.hermesHome
          cfg.workingDirectory
        ]
        ++ map (d: "${cfg.hermesHome}/${d}") stateSubdirs
      )
    }

    ${
      if cfg.configFile != null then
        "install -m 0600 -D ${cfg.configFile} ${home}/config.yaml"
      else
        ''
          ${mergeScript} ${generatedConfig} ${home}/config.yaml
          chmod 0600 ${home}/config.yaml
        ''
    }

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

    find ${home}/plugins -maxdepth 1 -type l -name 'nix-managed-*' -delete 2>/dev/null || true
    ${lib.concatMapStringsSep "\n" (plugin: ''
      if [ ! -f ${plugin}/plugin.yaml ]; then
        echo "hermes-podman: ERROR extraPlugins entry '${plugin}' has no plugin.yaml" >&2
        exit 1
      fi
      ln -sfn ${plugin} ${home}/plugins/nix-managed-${lib.getName plugin}
    '') cfg.extraPlugins}
  '';

  # The gateway and backend units run this in parallel, so serialize it.
  stateScript = pkgs.writeShellScript "hermes-podman-state" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p ${home}
    exec ${pkgs.util-linux}/bin/flock ${home} ${stateScriptInner}
  '';

  runState =
    if keepId then
      "${stateScript}"
    else
      "${pkgs.coreutils}/bin/env PATH=/run/wrappers/bin:/usr/bin:/bin ${podman}/bin/podman unshare ${stateScript}";

  # ── Container definition ────────────────────────────────────────────────
  usernsArgs = lib.optional keepId "--userns=keep-id:uid=${toString pcfg.permissions.uid},gid=${toString pcfg.permissions.gid}";

  volumeOpts = lib.optionalString (!keepId) ":U";

  volumes = [
    "${cfg.hermesHome}:${dataDir}${volumeOpts}"
  ]
  ++ lib.optional (!inHome) "${cfg.workingDirectory}:${cfg.workingDirectory}${volumeOpts}"
  ++ lib.optional (cfg.extraPlugins != [ ]) "/nix/store:/nix/store:ro"
  ++ pcfg.extraVolumes;

  containerEnvironment = {
    HERMES_HOME = dataDir;
    HERMES_MANAGED = managedSystem;
  }
  // cfg.environment;

  gatewayArgs = [
    "gateway"
    "run"
  ]
  ++ cfg.extraArgs;

  backendArgs = [
    cfg.backend.mode
    "--host"
    cfg.backend.host
    "--port"
    (toString cfg.backend.port)
  ]
  ++ lib.optional (cfg.backend.mode == "dashboard") "--no-open"
  ++ cfg.backend.extraArgs;

  mkContainer = args': {
    inherit (pcfg) image network;
    exec = lib.escapeShellArgs args';
    environment = containerEnvironment;
    environmentFile = cfg.environmentFiles;
    inherit volumes;
    extraPodmanArgs = usernsArgs ++ pcfg.extraArgs;
    extraConfig = {
      Unit = {
        After = pcfg.after;
        Wants = pcfg.wants;
      };
      Container.StopTimeout = pcfg.stopTimeout;
      Service = {
        ExecStartPre = runState;
        Restart = lib.mkForce cfg.restart;
        RestartSec = lib.mkForce (toString cfg.restartSec);
      };
    };
  };

  # ── Host wrappers ───────────────────────────────────────────────────────
  cliTarget =
    if cfg.gateway.enable then
      gatewayName
    else if cfg.backend.mode != "none" then
      backendName
    else
      "";

  # Same mounts and environment as the services, for the one-shot fallback.
  runFlags = lib.escapeShellArgs (
    usernsArgs
    ++ [
      "--network"
      pcfg.network
    ]
    ++ lib.concatMap (v: [
      "--volume"
      v
    ]) volumes
    ++ lib.concatMap (f: [
      "--env-file"
      f
    ]) cfg.environmentFiles
    ++ lib.concatLists (
      lib.mapAttrsToList (k: v: [
        "--env"
        "${k}=${v}"
      ]) containerEnvironment
    )
    ++ pcfg.extraArgs
  );

  mkCli =
    name: hermesArgs:
    pkgs.writeShellScriptBin name ''
      set -eu
      podman=${podman}/bin/podman
      target=${lib.escapeShellArg cliTarget}
      cwd=${lib.escapeShellArg containerWorkdir}

      case "$PWD" in
        ${lib.escapeShellArg cfg.workingDirectory}|${lib.escapeShellArg cfg.workingDirectory}/*)
          cwd=${lib.escapeShellArg containerWorkdir}"''${PWD#${cfg.workingDirectory}}"
          ;;
      esac

      flags=-i
      if [ -t 0 ] && [ -t 1 ]; then flags=-it; fi

      if [ -n "$target" ] && [ "$("$podman" container inspect --format '{{.State.Running}}' "$target" 2>/dev/null)" = true ]; then
        exec "$podman" exec $flags --workdir "$cwd" --env TERM "$target" hermes ${lib.escapeShellArgs hermesArgs} "$@"
      fi

      exec "$podman" run --rm $flags --workdir "$cwd" --env TERM ${runFlags} ${lib.escapeShellArg pcfg.image} ${lib.escapeShellArgs hermesArgs} "$@"
    '';

  backendUrl =
    let
      host =
        if
          lib.elem cfg.backend.host [
            "0.0.0.0"
            "::"
          ]
        then
          "127.0.0.1"
        else
          cfg.backend.host;
    in
    "http://${host}:${toString cfg.backend.port}";

  desktopPackage =
    let
      tokenFile = pgm.desktop.remoteTokenFile;
      tokenSnippet = "[ -r ${lib.escapeShellArg tokenFile} ] && export HERMES_DESKTOP_REMOTE_TOKEN=\"$(cat ${lib.escapeShellArg tokenFile})\"";
    in
    pkgs.symlinkJoin {
      name = "hermes-desktop-podman";
      paths = [ pgm.desktop.package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in "$out"/bin/*; do
          wrapProgram "$bin" \
            --set HERMES_HOME ${lib.escapeShellArg cfg.hermesHome} \
            --set HERMES_DESKTOP_REMOTE_URL ${lib.escapeShellArg backendUrl} \
            ${lib.optionalString (tokenFile != null) "--run ${lib.escapeShellArg tokenSnippet}"}
        done
      '';
    };

  webOpener = pkgs.writeShellScriptBin "${pgm.commandName}-web" ''
    exec ${pkgs.xdg-utils}/bin/xdg-open ${lib.escapeShellArg backendUrl}
  '';

  badDocName = name: lib.hasPrefix "/" name || lib.elem ".." (lib.splitString "/" name);
in
{
  # ════════════════════════════════════════════════════════════════════════
  # Options
  # ════════════════════════════════════════════════════════════════════════
  options.programs.hermes-podman = {
    commandName = mkOption {
      type = types.str;
      default = "hermes";
      description = ''
        Name of the CLI wrapper. The TUI wrapper is `<name>-tui` and the web
        opener is `<name>-web`.
      '';
      example = "hermes-podman";
    };

    cli.enable = mkOption {
      type = types.bool;
      default = cfg.enable;
      defaultText = literalExpression "config.services.hermes-podman.enable";
      description = "Install the CLI wrapper that runs `hermes` inside the container.";
    };

    tui.enable = mkOption {
      type = types.bool;
      default = cfg.enable;
      defaultText = literalExpression "config.services.hermes-podman.enable";
      description = "Install `<commandName>-tui`, which runs `hermes --tui` inside the container.";
    };

    web.enable = mkEnableOption ''
      the web dashboard. It runs in the backend container and
      `<commandName>-web` opens it in the browser
    '';

    desktop = {
      enable = mkEnableOption ''
        the Hermes Desktop app. It is wrapped to use the backend container
        instead of a local runtime in ~/.hermes
      '';
      package = mkOption {
        type = types.package;
        default = pkgs.hermes.desktop;
        defaultText = literalExpression "pkgs.hermes.desktop";
        description = "The Hermes Desktop package to wrap.";
      };
      remoteTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Runtime path of a file that holds the session token. It is exported
          as HERMES_DESKTOP_REMOTE_TOKEN at launch. Needed only when the
          backend requires authentication (non-loopback host).
        '';
      };
    };
  };

  options.services.hermes-podman = {
    enable = mkEnableOption "Hermes Agent in rootless Podman containers";

    package = mkOption {
      type = types.package;
      default = pkgs.hermes.full;
      defaultText = literalExpression "pkgs.hermes.full";
      description = ''
        The hermes-agent package. The runtime is the container image, so this
        is used only at build time, to read `_config_version` for config.yaml.
        It is not evaluated when `configVersion` is set.
      '';
    };

    configVersion = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        The `_config_version` to stamp into config.yaml. When null, the value
        is read from `package`. It must match the image that you run.
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
        Path to an existing config.yaml. It replaces the `settings` option,
        is installed unchanged, and overwrites runtime edits on each activation.
      '';
    };

    settings = mkOption {
      type = deepConfigType;
      default = { };
      description = ''
        The Hermes configuration as an attribute set. Definitions from all
        modules are deep-merged. The merge into the config.yaml on disk is
        also deep: these keys replace the keys on disk, all other keys
        (written at runtime) are kept.
      '';
      example = literalExpression ''
        {
          model.default = "anthropic/claude-sonnet-4";
          terminal.backend = "local";
          compression = { enabled = true; threshold = 0.85; };
        }
      '';
    };

    environmentFiles = mkOption {
      # `str`, not `path`: a path literal would copy the secret into the Nix store.
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Paths to environment files that contain secrets. They are read at
        runtime, appended to $HERMES_HOME/.env, and passed to the containers
        with --env-file. .env is rewritten from scratch on each activation.
      '';
      example = literalExpression ''[ config.sops.secrets."hermes/env".path ]'';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Non-secret environment variables, written to $HERMES_HOME/.env and
        given to the containers. Do not put secrets here: the Nix store is
        world-readable.
      '';
    };

    authFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Runtime path of the initial auth.json (OAuth credentials). It is
        copied only when auth.json does not exist, so refreshed tokens stay.
      '';
      example = literalExpression ''config.sops.secrets."hermes/auth".path'';
    };

    substituteVars = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Variable names whose ''${NAME} placeholders in config.yaml are replaced
        at runtime with values read from environmentFiles, so secrets stay out
        of the Nix store.
      '';
      example = [ "OMNIROUTE_API_KEY" ];
    };

    authFileForceOverwrite = mkOption {
      type = types.bool;
      default = false;
      description = "Always overwrite auth.json from authFile on activation.";
    };

    documents = mkOption {
      type = documentsType;
      default = { };
      description = ''
        Workspace files installed into workingDirectory. Keys are relative
        paths, values are strings or paths. SOUL.md and memories/ belong in
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
        Files installed into HERMES_HOME. Hermes reads SOUL.md and the memory
        files from here, not from the working directory.
      '';
      example = literalExpression ''
        {
          "SOUL.md" = "You are a helpful AI assistant.";
          "memories/USER.md" = ./USER.md;
        }
      '';
    };

    mcpServers = mkOption {
      type = types.attrsOf mcpServerType;
      default = { };
      description = ''
        MCP server configurations (merged into settings.mcp_servers). A stdio
        server runs inside the container, so its command must exist in the image.
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
        Directory-based plugin packages symlinked into the plugins directory.
        Each needs plugin.yaml and __init__.py at its root. The host
        /nix/store is mounted read-only into the containers.
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

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra command-line arguments for `hermes gateway run`.";
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

    backend = {
      mode = mkOption {
        type = types.enum [
          "none"
          "serve"
          "dashboard"
        ];
        default =
          if pgm.web.enable then
            "dashboard"
          else if pgm.desktop.enable then
            "serve"
          else
            "none";
        defaultText = literalExpression ''"dashboard" with web.enable, "serve" with desktop.enable, else "none"'';
        description = ''
          The backend container to run.

          - "none":      no backend
          - "serve":     headless backend (/api/ws and /api/pty) for Hermes Desktop
          - "dashboard": everything "serve" gives, plus the browser admin panel
        '';
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          Address the backend binds to (the container uses the host network).
          A non-loopback address enables the authentication gate, so configure
          credentials first. Requests whose Host header differs from the bound
          address are refused.
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
        description = "Extra command-line arguments for the backend command.";
      };
    };

    podman = {
      namePrefix = mkOption {
        type = types.str;
        default = "hermes";
        description = ''
          Container name prefix. Containers are `<prefix>-gateway` and
          `<prefix>-backend`, so the units are `podman-<prefix>-gateway.service`
          and `podman-<prefix>-backend.service`.
        '';
      };

      image = mkOption {
        type = types.str;
        default = "docker.io/nousresearch/hermes-agent:latest";
        description = "OCI image to run. Pin a tag that matches `package` or `configVersion`.";
      };

      network = mkOption {
        type = types.str;
        default = "host";
        description = "Podman network mode.";
      };

      permissions = {
        mode = mkOption {
          type = types.enum [
            "keep-id"
            "chown"
          ];
          default = "keep-id";
          description = ''
            How file ownership is handled.

            - "keep-id": the host user is mapped to the image user, so
              hermesHome stays owned by you and the CLI, desktop app and
              container all share it. No recursive chown.
            - "chown":   the volume is mounted with `:U` and the state is
              prepared inside `podman unshare`. Files end up owned by a subuid,
              so the host user cannot edit them.
          '';
        };
        uid = mkOption {
          type = types.int;
          default = 10000;
          description = "UID of the user inside the image (keep-id mode).";
        };
        gid = mkOption {
          type = types.int;
          default = 10000;
          description = "GID of the user inside the image (keep-id mode).";
        };
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
        description = "Systemd units the container services are ordered after.";
      };
      wants = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Systemd units the container services want.";
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
    {
      home.packages =
        lib.optional pgm.cli.enable (mkCli pgm.commandName [ ])
        ++ lib.optional pgm.tui.enable (mkCli "${pgm.commandName}-tui" [ "--tui" ])
        ++ lib.optional pgm.desktop.enable desktopPackage
        ++ lib.optional pgm.web.enable webOpener;

      warnings =
        lib.optional
          (!cfg.enable && (pgm.cli.enable || pgm.tui.enable || pgm.web.enable || pgm.desktop.enable))
          "programs.hermes-podman is enabled, but services.hermes-podman.enable is not. The wrappers have no container to talk to.";
    }

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
            assertion = !pgm.desktop.enable || keepId;
            message = "programs.hermes-podman.desktop needs podman.permissions.mode = \"keep-id\": the app writes logs into hermesHome as the host user.";
          }
          {
            assertion = !pgm.web.enable || cfg.backend.mode == "dashboard";
            message = "programs.hermes-podman.web.enable needs services.hermes-podman.backend.mode = \"dashboard\".";
          }
          {
            assertion = !pgm.desktop.enable || cfg.backend.mode != "none";
            message = "programs.hermes-podman.desktop.enable needs a backend container (backend.mode = \"serve\" or \"dashboard\").";
          }
          {
            assertion =
              lib.length (map lib.getName cfg.extraPlugins)
              == lib.length (lib.unique (map lib.getName cfg.extraPlugins));
            message = "services.hermes-podman.extraPlugins: duplicate plugin names: ${toString (map lib.getName cfg.extraPlugins)}. With fetchFromGitHub, set name = \"plugin-name\".";
          }
          {
            assertion =
              !(lib.any badDocName (lib.attrNames cfg.documents ++ lib.attrNames cfg.hermesHomeFiles));
            message = "services.hermes-podman.documents / hermesHomeFiles: a key must be a relative path without `..`.";
          }
        ];

        warnings =
          lib.optional (cfg.backend.mode == "none" && !cfg.gateway.enable)
            "services.hermes-podman is enabled, but neither gateway.enable nor backend.mode starts a container.";

        services.podman.enable = true;

        home.activation.hermesPodmanSetup = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] (
          if keepId then
            "run ${stateScript}"
          else
            ''run env PATH="/run/wrappers/bin:$PATH:/usr/bin" ${podman}/bin/podman unshare ${stateScript}''
        );
      }

      (mkIf cfg.gateway.enable {
        services.podman.containers.${gatewayName} = mkContainer gatewayArgs;
      })

      (mkIf (cfg.backend.mode != "none") {
        services.podman.containers.${backendName} = mkContainer backendArgs;
      })
    ]))

    {
      home.activation.hermesPodmanRestart =
        let
          units = [
            "podman-hermes-gateway.service"
            "podman-hermes-backend.service"
          ];
          settingsFile = pkgs.writeText "hermes-settings.json" (
            builtins.toJSON config.services.hermes-podman.settings
          );
          stateFile = "${config.xdg.stateHome}/hermes-podman/fingerprint";
          sc = "${pkgs.systemd}/bin/systemctl --user";
        in
        lib.hm.dag.entryAfter [ "reloadSystemd" "hermesPodmanSetup" ] ''
          if [ -z "''${DRY_RUN:-}" ]; then
            fp=$(
              {
                cat ${settingsFile}
                ${sc} cat ${lib.escapeShellArgs units} 2>/dev/null || true
                cat ${cfg.hermesHome}/.env 2>/dev/null || true
              } | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1
            )
            mkdir -p "$(dirname ${stateFile})"
            if [ -f ${stateFile} ] && [ "$(cat ${stateFile})" != "$fp" ]; then
              ${sc} restart ${lib.escapeShellArgs units} || true
            fi
            echo "$fp" > ${stateFile}
          fi
        '';
    }
  ];
}
