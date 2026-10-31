{
  pkgs,
  lib,
  base,
}:
let
  app = base.app "hermes-agent";
  coding = base.group "coding";

  mountRoot = "/run/hermes-mounts";
  mountIn = "/workspaces";
in
{
  inherit mountRoot mountIn;

  vars = {
    mount_root = mountRoot;
    mount_in = mountIn;
    container = "hermes";
    unit = "podman-hermes.service";
    bot_user = app.username;
    bot_host_uid = toString (200000 + app.uid - 1);
    coding_gid = toString coding.gid;
    hermes_home = "/app/data";
    default_workdir = "/workspaces";
    hermes_bin = "hermes";
    omh_bin = "omh";
    container_path = lib.concatStringsSep ":" [
      "/etc/profiles/per-user/${app.username}/bin"
      "/home/${app.username}/.nix-profile/bin"
      "/run/current-system/sw/bin"
    ];
    shell = lib.getExe base.tools.shell;
    podman = "${pkgs.podman}/bin/podman";
    machinectl = "${pkgs.systemd}/bin/machinectl";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    journalctl = "${pkgs.systemd}/bin/journalctl";
    bindfs = "${pkgs.bindfs}/bin/bindfs";
    umount = "${pkgs.util-linux}/bin/umount";

    refs = {
      dotfiles-ref = {
        src = "/workspaces/dotfiles";
        mode = "ro";
      };
    };
  };
}
