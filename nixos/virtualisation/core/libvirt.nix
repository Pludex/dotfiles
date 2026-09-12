{
  base,
  pkgs,
  inputs,
  ...
}:
{
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    libvirt
    qemu
    OVMFFull.fd
    inputs.nix-virt.packages.${pkgs.stdenv.system}.default
  ];

  users.users.${base.username}.extraGroups = [ "libvirtd" ];
  programs.dconf.enable = true;

  networking.firewall.trustedInterfaces = [ "virbr0" ];
  imports = [ inputs.nix-virt.nixosModules.default ];
}
