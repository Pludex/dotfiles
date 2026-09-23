{ base, pkgs, ... }:
{
  system.stateVersion = "26.05";

  time.timeZone = base.timeZone;
  i18n.defaultLocale = base.locale;

  environment.systemPackages = [ pkgs.mkcert ];

  imports = [
    ./keyboard
    ./options
    ./audio.nix
    ./bluetooth.nix
    ./networking.nix
    ./nix-config.nix
    ./security.nix
    ./shell.nix
    ./sops.nix
    ./users.nix
    ./xdg.nix
  ];
}
