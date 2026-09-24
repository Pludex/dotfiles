{ base, ... }:
{
  home.username = base.username;
  home.homeDirectory = base.abs.home;
  home.stateVersion = "26.05";

  home.sessionVarible = base.tools.envvars;

  imports = [
    ./input-method
    ./programs
    ./services
    ./gtk.nix
    ./man.nix
    ./nix-config.nix
    ./sops.nix
    ./style.nix
    ./systemd.nix
  ];
}
