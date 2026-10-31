{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  inherit (h) cfg profileUnits syncUnits;
  inherit (config) app;

  mergeEnv = h.mkMergeEnv (h.templatePath "hermes-env") "${cfg.hermesHome}/.env";
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
    systemd.user.services.hermes-agent = {
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

    systemd.user.services.hermes-backend = {
      Unit = {
        After = [ "sops-nix.service" ];
        Wants = [ "sops-nix.service" ];
      };
      Service.EnvironmentFile = [ (h.templatePath "hermes-env") ];
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
