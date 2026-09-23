{
  pkgs,
  base,
  config,
  ...
}:
{
  services.vaultwarden = {
    enable = true;

    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      DOMAIN = "https://glider-crafter-retrace.ngrok-free.dev";

      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = false;
    };

    # backupDir = "/var/backup/vaultwarden";
  };

  systemd.services.ngrok-vaultwarden = {
    description = "Ngrok Tunnel for Vaultwarden";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ngrok}/bin/ngrok http 8222 --domain=glider-crafter-retrace.ngrok-free.dev";
      Restart = "always";
      User = base.username;
    };
  };

  systemd.services.vaultwarden-backup-nix = {
    description = "Vaultwarden Backup";
    after = [
      "network.target"
      "vaultwarden.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      VAULTWARDEN_STATE_DIR="/var/lib/vaultwarden"
      export VAULTWARDEN_STATE_DIR
      ${pkgs.myPkgs.vaultwarden-sync}/bin/vaultwarden-sync export
    '';
  };

  systemd.timers.vaultwarden-backup-nix = {
    description = "Timer for automated Vaultwarden backup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitActiveSec = "72h";
      Persistent = true;
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "vaultwarden-sync" ''
      VAULTWARDEN_SERVICE="vaultwarden.service"
      VAULTWARDEN_STATE_DIR="/var/lib/vaultwarden"

      export VAULTWARDEN_SERVICE
      export VAULTWARDEN_STATE_DIR

      ${pkgs.myPkgs.vaultwarden-sync}/bin/vaultwarden-sync "$@"
    '')
  ];
}
