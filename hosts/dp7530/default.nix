{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_cachyos;
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
      configurationLimit = 10;
      settings = {
        timeout = 4;
        force-menu = false;
        console-mode = "max";
      };
    };

    consoleLogLevel = 0;
    initrd.verbose = false;

    plymouth = {
      enable = true;
      theme = "bgrt";
    };
  };

  services.scx.enable = true;
  services.scx.scheduler = "scx_rustland";

  host-config.gpuDrivers = [ "intel" ];

  imports = [
    ./hardware-configuration.nix

    inputs.lanzaboote.nixosModules.lanzaboote
  ];
}
