{
  config,
  lib,
  pkgs,
  base,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs base; };
  inherit (h)
    cfg
    profileUnits
    syncUnits
    coreUnits
    units
    ;
  inherit (config) app;

  mergeEnv = h.mkMergeEnv (h.templatePath "hermes-env") "${cfg.hermesHome}/.env";

  # The token must not appear on a command line, so it goes through the environment.
  dashboardLaunch = pkgs.writeShellScript "hermes-dashboard-launch" ''
    set -euo pipefail

    token_file=${h.secretPath cfg.sessionTokenSecret}
    if [ ! -r "$token_file" ]; then
      echo "hermes-dashboard: cannot read the session token file '$token_file'" >&2
      exit 1
    fi

    HERMES_DASHBOARD_SESSION_TOKEN="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$token_file")"
    if [ -z "$HERMES_DASHBOARD_SESSION_TOKEN" ]; then
      echo "hermes-dashboard: the session token file '$token_file' is empty" >&2
      exit 1
    fi
    export HERMES_DASHBOARD_SESSION_TOKEN

    exec ${lib.getExe' cfg.package "hermes"} dashboard \
      --host ${cfg.dashboard.host} --port ${toString cfg.dashboard.port} --no-open
  '';
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs h.allSecrets (_: { });
    sops.templates."hermes-env".content = h.renderEnv cfg.main;

    services.hermes-agent = {
      enable = true;
      inherit (cfg) package hermesHome;
      gateway.enable = true;
      restart = "on-failure";

      backend = {
        mode = "dashboard";
        sessionTokenFile = h.secretPath cfg.sessionTokenSecret;
      };

      settings = h.settingsOf cfg.main;
      mcpServers = h.mcpToYaml (h.effectiveMcp cfg.main);

      environment = lib.optionalAttrs cfg.apiServer.enable {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = cfg.apiServer.host;
        API_SERVER_PORT = toString cfg.apiServer.port;
      };

      environmentFiles = [ (h.templatePath "hermes-env") ];
    };

    programs.hermes-agent = {
      enable = true;
      inherit (cfg) package;
      desktop.enable = false;
    };

    # The single host gateway serves every profile, so it restarts with them.
    systemd.user.services.${units.agent} = {
      Unit = {
        After = [
          "sops-nix.service"
          "podman-omniroute.service"
          "hermes-env-merge.service"
        ]
        ++ syncUnits
        ++ profileUnits;
        Wants = [
          "sops-nix.service"
          "omniroute-bootstrap.service"
          "hermes-env-merge.service"
        ]
        ++ syncUnits
        ++ profileUnits;
        PartOf = profileUnits;
      };
      Service.EnvironmentFile = [ (h.templatePath "hermes-env") ];
    };

    # Replaces upstream's hermes-backend: that unit hardcodes the bind address.
    systemd.user.services.${units.dashboard} = {
      Unit = {
        Description = "Hermes web dashboard and desktop backend";
        After = [
          "sops-nix.service"
          "hermes-env-merge.service"
        ];
        Wants = [
          "sops-nix.service"
          "hermes-env-merge.service"
        ];
      };
      Service = {
        ExecStart = "${dashboardLaunch}";
        Environment = [
          "HERMES_HOME=${cfg.hermesHome}"
          "HERMES_MANAGED=home-manager"
          "PATH=${
            lib.makeBinPath [
              cfg.package
              pkgs.bash
              pkgs.coreutils
              pkgs.git
            ]
          }"
        ];
        EnvironmentFile = [ (h.templatePath "hermes-env") ];
        WorkingDirectory = config.home.homeDirectory;
        NoNewPrivileges = true;
        PrivateTmp = true;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Published ports do not reach a loopback-only listener inside the guest.
    systemd.user.services."${units.dashboard}-proxy" = {
      Unit = {
        Description = "Expose the Hermes dashboard on the container interface";
        After = [ "${units.dashboard}.service" ];
        PartOf = [ "${units.dashboard}.service" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.socat} TCP-LISTEN:${toString cfg.dashboard.proxy.port},bind=${cfg.dashboard.proxy.host},fork,reuseaddr TCP:${cfg.dashboard.host}:${toString cfg.dashboard.port}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Upstream's own dashboard unit would bind the same port
    systemd.user.services.hermes-backend.Install.WantedBy = lib.mkForce [ ];

    systemd.user.services.hermes-env-merge = {
      Unit = {
        Description = "Merge sops-rendered secrets into Hermes .env";
        After = [ "sops-nix.service" ];
        Wants = [ "sops-nix.service" ];
        Before = coreUnits;
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mergeEnv}";
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep ]}"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };

    home.sessionVariables = {
      XDG_RUNTIME_DIR = "/run/user/${toString app.uid}";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString app.uid}/bus";
    };
  };
}
