{
  pkgs,
  lib,
  base,
  ...
}:
let
  app = base.app "hermes-agent";
  inherit (app) container;
  inherit (import ./hermes-vars.nix { inherit pkgs lib base; }) mountRoot mountIn;
in
{
  virtualisation.oci-containers.containers.${container.name}.volumes = [
    "${mountRoot}:${mountIn}:rslave"
  ];

  systemd.services.hermes-mount-root = {
    description = "Shared mount root for hermesctl";
    wantedBy = [ "multi-user.target" ];
    before = [ container.unit ];
    requiredBy = [ container.unit ];
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
