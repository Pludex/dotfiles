{
  hosts.ci-runner = {
    system = "x86_64-linux";
    role = "server";
    modules.nixos =
      { lib, ... }:
      {
        documentation.enable = false;
        boot.loader.systemd-boot.enable = lib.mkDefault true;
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
      };
  };
}
