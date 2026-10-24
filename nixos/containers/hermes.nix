{
  inputs,
  pkgs,
  base,
  ...
}:
let
  guest = inputs.self.nixosConfigurations.hermes;
  toplevel = guest.config.system.build.toplevel;
in
{
  virtualisation.podman.enable = true;

  users.users.hermes-host = {
    isNormalUser = true;
    linger = true;
    autoSubUidGidRange = true;
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.hermes = {
      image = "hermes-base:latest";
      imageFile = pkgs.dockerTools.buildImage {
        name = "hermes-base";
        tag = "latest";
      };
      cmd = [ "${toplevel}/init" ];
      volumes = [
        "/nix/store:/nix/store:ro"
        "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
        # "${base.ai.hermes-agnet.abs.data}:/app/data:U"
      ];
      extraOptions = [
        "--systemd=always"
        "--security-opt=no-new-privileges"
      ];
      podman.user = "hermes-host";
    };
  };

  systemd.services.podman-hermes = {
    restartIfChanged = true;
    restartTriggers = [
      toplevel
      # add other inputs here, e.g. a sops file whose content should trigger a restart
      # config.sops.secrets.hermes-age-key.sopsFile
    ];
  };
}
