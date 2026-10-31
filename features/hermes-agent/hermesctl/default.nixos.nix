{
  pkgs,
  lib,
  base,
  ...
}:
let
  inherit (import ./hermes-vars.nix { inherit pkgs lib base; }) mountRoot mountIn;
in
{
  virtualisation.oci-containers.containers.hermes.volumes = [
    "${mountRoot}:${mountIn}:rslave"
  ];

  systemd.services.hermes-mount-root = {
    description = "Shared mount root for hermesctl";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-hermes.service" ];
    requiredBy = [ "podman-hermes.service" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p ${mountRoot}
      mountpoint -q ${mountRoot} || mount --bind ${mountRoot} ${mountRoot}
      mount --make-rshared ${mountRoot}
    '';
    preStop = "umount -R ${mountRoot} || true";
  };
}
