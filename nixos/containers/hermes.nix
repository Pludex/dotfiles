{
  inputs,
  pkgs,
  base,
  config,
  ...
}:
let
  guest = inputs.self.nixosConfigurations.hermes;
  toplevel = guest.config.system.build.toplevel;
  bot = base.botOf "hermes";
in
{
  virtualisation.podman.enable = true;

  sops.secrets."age-keys/hermes" = {
    owner = "hermes-host";
    mode = "0400";
    # Restart the container when the key content changes
    restartUnits = [ "podman-hermes.service" ];
  };

  users.users.hermes-host = {
    isSystemUser = true;
    linger = true;
    home = "/var/lib/hermes-host";
    createHome = true;
    autoSubUidGidRange = true;
    group = "users-host";
    extraGroups = [
      "keys" # of sops-nix
      "coding"
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
          mkdir -p /private /workspaces
          touch /private/hermes.age-key.txt
          chown ${toString bot.uid} -R /private /workspaces
        '';
      };
      cmd = [ "${toplevel}/init" ];
      volumes = [
        "/nix/store:/nix/store:ro"
        "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
        "/workspaces/dotfiles:/workspaces/dotfiles-ref:ro"
        # "${base.ai.hermes-agnet.abs.data}:/app/data:U"
        "${config.sops.secrets."age-keys/hermes".path}:${bot.age.privateKeyPath}:ro,Z"
      ];
      extraOptions = [
        "--systemd=always"
        "--security-opt=no-new-privileges"
        "--group-add=keep-groups"
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
}
