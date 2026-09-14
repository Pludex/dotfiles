{ base, ... }:
{
  home.username = base.username;
  home.homeDirectory = base.paths.home;
  home.stateVersion = "26.05";

  imports = [
    ./input-method
    ./programs
    ./services
    ./gtk.nix
    ./man.nix
    ./nix-config.nix
    ./sops.nix
    ./theme.nix
    ./systemd.nix
  ];
}
