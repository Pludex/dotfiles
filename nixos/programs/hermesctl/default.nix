{
  pkgs,
  lib,
  base,
  ...
}:
let
  app = base.app "hermes-agent";
  coding = base.group "coding";

  mountRoot = "/run/hermes-mounts";
  mountIn = "/mnt/host";

  vars = {
    mount_root = mountRoot;
    mount_in = mountIn;
    container = "hermes";
    bot_user = app.username;
    bot_host_uid = toString (200000 + app.uid - 1);
    coding_gid = toString coding.gid;
    hermes_home = "/app/data";
    default_workdir = "/workspaces";
    hermes_bin = "hermes";
    container_path = lib.concatStringsSep ":" [
      "/etc/profiles/per-user/${app.username}/bin"
      "/home/${app.username}/.nix-profile/bin"
      "/run/current-system/sw/bin"
    ];
    shell = lib.getExe base.tools.shell;
    podman = "${pkgs.podman}/bin/podman";
    machinectl = "${pkgs.systemd}/bin/machinectl";
    bindfs = "${pkgs.bindfs}/bin/bindfs";
    umount = "${pkgs.util-linux}/bin/umount";
  };
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
      mount --make-private ${mountRoot}
      mount --make-rshared ${mountRoot}
    '';
    preStop = "umount -R ${mountRoot} || true";
  };

  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "hermesctl" { doCheck = false; } (
      "CFG = ${builtins.toJSON vars}\n" + builtins.readFile ./hermesctl.py
    ))
  ];
}
