{
  pkgs,
  lib,
  base,
}:
let
  app = base.app "hermes-agent";
  coding = base.group "coding";

  mountRoot = "/run/${app.username}-mounts";
  mountIn = app.container.workspaces;

  # mounted at boot by hermes-refs.service (see the mount module)
  refs = {
    dotfiles-ref = {
      src = "/workspaces/dotfiles";
      mode = "ro";
    };
  };

  refsUnit = "hermes-refs.service";
in
{
  inherit
    mountRoot
    mountIn
    refs
    refsUnit
    ;

  vars = {
    mount_root = mountRoot;
    mount_in = mountIn;
    container = app.container.name;
    unit = app.container.unit;
    bot_user = app.username;
    bot_host_uid = toString app.users.container.uid;
    coding_gid = toString coding.gid;
    hermes_home = app.container.data;
    default_workdir = app.container.workspaces;
    hermes_bin = "hermes";
    omh_bin = "omh";
    container_path = lib.concatStringsSep ":" [
      "/etc/profiles/per-user/${app.username}/bin"
      "${app.home}/.nix-profile/bin"
      "/run/current-system/sw/bin"
    ];
    shell = lib.getExe base.tools.shell;
    podman = "${pkgs.podman}/bin/podman";
    machinectl = "${pkgs.systemd}/bin/machinectl";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    journalctl = "${pkgs.systemd}/bin/journalctl";
    bindfs = "${pkgs.bindfs}/bin/bindfs";
    umount = "${pkgs.util-linux}/bin/umount";

    inherit refs;
    refs_unit = refsUnit;
  };
}
