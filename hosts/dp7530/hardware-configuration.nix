{
  config,
  lib,
  modulesPath,
  ...
}:

let
  rootDevice = "/dev/disk/by-uuid/10f022b5-943f-47c3-8e2c-588bda93f425";
  dataDevice = "/dev/disk/by-uuid/609dd9b6-ae03-4968-9df9-42e40c3aff7c";

  btrfsOptions = subvol: [
    "subvol=${subvol}"
    "compress=zstd:3"
    "noatime"
    "discard=async"
  ];
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = rootDevice;
    fsType = "btrfs";
    options = btrfsOptions "@";
  };

  fileSystems."/var/log" = {
    device = rootDevice;
    fsType = "btrfs";
    options = btrfsOptions "@log";
  };

  fileSystems."/nix" = {
    device = rootDevice;
    fsType = "btrfs";
    options = btrfsOptions "@nix";
  };

  fileSystems."/home" = {
    device = dataDevice;
    fsType = "btrfs";
    options = btrfsOptions "@home";
  };

  fileSystems."/workspaces" = {
    device = dataDevice;
    fsType = "btrfs";
    options = btrfsOptions "@workspaces";
  };

  fileSystems."/data" = {
    device = dataDevice;
    fsType = "btrfs";
    options = btrfsOptions "@data";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/41DC-1183";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
