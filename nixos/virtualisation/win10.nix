{ inputs, ... }:
let
  nixvirt = inputs.nix-virt;
in

{
  virtualisation.libvirt.connections."qemu:///system" = {
    domains = [
      {
        active = true;
        definition = nixvirt.lib.domain.writeXML (
          nixvirt.lib.domain.templates.windows {
            name = "win10";
            uuid = "e54c1596-dcc8-452c-a1c9-970a5ceec7db";
            memory = {
              count = 8;
              unit = "GiB";
            };
            vcpu = {
              count = 4;
            };
            backing_vol = null;
            # storage_vol = "/var/lib/libvirt/images/win10.qcow2";
            storage_vol = {
              pool = "default";
              volume = "win10.qcow2";
            };

            # install_vol = "/var/lib/libvirt/images/win10.iso";
            bridge_name = "virbr0";
            nvram_path = "/var/lib/libvirt/qemu/nvram/win10_VARS.fd";
            virtio_net = true;
            virtio_drive = true;
            install_virtio = true;
          }
        );
      }
    ];

    pools = [
      {
        definition = nixvirt.lib.pool.writeXML {
          name = "default";
          uuid = "0f13531e-0e57-4bc3-a8d8-f88d42c782fc";
          type = "dir";
          target.path = "/var/lib/libvirt/images";
        };

        active = true;
        volumes = [
          {
            definition = nixvirt.lib.volume.writeXML {
              name = "win10.qcow2";
              capacity = {
                count = 100;
                unit = "GiB";
              };
            };
          }
        ];
      }
    ];
  };
}
