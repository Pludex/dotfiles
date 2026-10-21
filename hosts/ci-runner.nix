{
  hosts.ci-runner = {
    system = "x86_64-linux";
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
