{ pkgs, modulesPath, ... }:
{
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
  boot.zfs.forceImportRoot = false;
  disabledModules = [ "profiles/zfs.nix" ];
  boot.supportedFilesystems = pkgs.lib.mkForce [
    "ext4"
    "btrfs"
    "vfat"
    "fat32"
  ];
}
