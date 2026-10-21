{
  base,
  pkgs,
  lib,
  config,
  ...
}:
{
  config = {
    system.stateVersion = "26.05";

    time.timeZone = base.timeZone;
    i18n.defaultLocale = base.locale;

    environment.systemPackages = [ pkgs.mkcert ];

    boot.isContainer = config.isContainer;
  };

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

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
