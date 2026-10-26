{
  hosts.nixos-container = {
    system = "x86_64-linux";
    modules.nixos = {
      isContainer = true;
      boot.isContainer = true;
    };
  };

  hosts.container = {
    system = "x86_64-linux";
    modules.nixos =
      { lib, pkgs, ... }:
      {
        isContainer = true;
        boot.isContainer = true;

        # Podman already mounts /nix/store read-only; remounting it
        # from inside the rootless userns fails with "permission denied"
        boot.nixStoreMountOpts = [ ];

        # Skip the "specialfs" snippet: /proc, /run and /run/keys are
        # mounted by podman and cannot be remounted in a rootless userns
        system.activationScripts.specialfs = lib.mkForce "";

        # Bind-mounted by podman, so they cannot be replaced by store symlinks
        environment.etc = {
          hostname.enable = lib.mkForce false;
          hosts.enable = lib.mkForce false;
        };

        # Mounting tmpfs on /run/wrappers is denied in the userns, and
        # setuid wrappers are useless with no-new-privileges anyway
        security.enableWrappers = false;

        # dbus-broker fails to start here (ENOPKG); use the reference daemon
        services.dbus.implementation = "dbus";

        # Not useful or not supported inside a rootless container
        services.nscd.enable = false;
        system.nssModules = lib.mkForce [ ];
        systemd.oomd.enable = false;

        # Lets `podman exec` find binaries without full paths
        environment.variables.PATH = "/run/current-system/sw/bin:/bin";

        systemd.tmpfiles.rules = [
          "d /run/wrappers/bin 0755 root root -"
          "L+ /run/wrappers/bin/unix_chkpwd - - - - ${pkgs.pam}/bin/unix_chkpwd"
        ];
      };
  };
}
