{
  hosts.dp7530 = {
    system = "x86_64-linux";
    gpus = [ "intel" ];

    modules.nixos =
      {
        pkgs,
        lib,
        inputs,
        ...
      }:
      {
        imports = [
          ./hardware-configuration.nix
          inputs.lanzaboote.nixosModules.lanzaboote
        ];

        boot = {
          kernelPackages = pkgs.linuxPackages_zen;
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

          plymouth = {
            enable = true;
            theme = "bgrt";
          };

          tmp.useTmpfs = true;

          kernel.sysctl = {
            "vm.swappiness" = 180;
            "vm.page-cluster" = 0;
          };
        };

        powerManagement.cpuFreqGovernor = "performance";

        services = {
          scx-loader = {
            enable = true;
            config = {
              default_sched = "scx_bpfland";
              default_mode = "Auto";
            };
          };

          thermald.enable = true;
        };
      };
  };
}
