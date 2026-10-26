{
  inputs,
  pkgs,
  base,
  config,
  lib,
  ...
}:
let
  guest = inputs.self.nixosConfigurations.hermes;
  toplevel = guest.config.system.build.toplevel;
  bot = base.botOf "hermes";
  coding = base.groupOf "coding";
  app = base.appOf "hermes-agent";
in
{
  virtualisation.podman.enable = true;

  sops.secrets."age-keys/hermes" = {
    owner = null;
    uid = 200000 + bot.uid - 1;
    mode = "0400";
    restartUnits = [ "podman-hermes.service" ];
  };

  users.users.hermes-host = {
    isSystemUser = true;
    linger = true;
    home = "/var/lib/hermes-host";
    createHome = true;
    group = "users-host";
    extraGroups = [
      "keys" # of sops-nix
      "coding"
    ];

    autoSubUidGidRange = false;
    subUidRanges = [
      {
        startUid = 200000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = coding.gid;
        count = 1;
      } # intermediate gid 1 -> host coding
      {
        startGid = 200000;
        count = 65536;
      } # intermediate gid 2..65537
    ];
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.hermes = {
      image = "hermes-agent";
      # Nearly empty image: the real system comes from the mounted /nix/store
      imageFile = pkgs.dockerTools.buildImage {
        name = "hermes-agent";
        tag = "latest";

        # Lets `podman exec` find binaries without full paths
        config.Env = [
          "PATH=/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
        runAsRoot = ''
          mkdir -p /private /workspaces /app/data
          touch ${bot.age.privateKeyPath}
          chown ${toString bot.uid}:${toString coding.gid} -R /workspaces
          chown ${toString bot.uid}:${toString coding.gid} -R /app
        '';
      };
      cmd = [ "${toplevel}/init" ];
      volumes = [
        "/nix/store:/nix/store:ro"
        "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
        "/workspaces/dotfiles:/workspaces/dotfiles-ref:ro"
        "${app.abs.data}:/app/data"
        "${config.sops.secrets."age-keys/hermes".path}:${bot.age.privateKeyPath}:ro,Z"
      ];
      extraOptions = [
        "--network=host"
        "--systemd=always"
        "--security-opt=no-new-privileges"
        "--uidmap=0:0:1"
        "--uidmap=1:1:65536"
        "--gidmap=0:0:1"
        "--gidmap=1:2:${toString (coding.gid - 1)}"
        "--gidmap=${toString coding.gid}:1:1"
        "--gidmap=${toString (coding.gid + 1)}:${toString (coding.gid + 1)}:${toString (65537 - coding.gid)}"
      ];
      podman.user = "hermes-host";
    };
  };

  systemd.services.podman-hermes = {
    restartIfChanged = true;
    restartTriggers = [
      toplevel
      config.sops.secrets."age-keys/hermes".path
    ];
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "login-hermes-container" ''
      exec sudo ${pkgs.systemd}/bin/machinectl shell hermes-host@ \
        ${pkgs.podman}/bin/podman exec -it --user ${bot.username} hermes ${lib.getExe base.tools.shell} "$@"
    '')
  ];
}
