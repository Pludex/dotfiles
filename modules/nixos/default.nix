{
  base,
  pkgs,
  lib,
  config,
  ...
}:
let
  bot = base.botOf config.name;
in
{
  config = lib.mkMerge [
    {
      system.stateVersion = "26.05";

      time.timeZone = base.timeZone;
      i18n.defaultLocale = base.locale;

      environment.systemPackages = [
        pkgs.mkcert
        pkgs.nix
      ];

      documentation.man.cache.enable = false;
    }

    (lib.mkIf config.isContainer {
      inherit bot;
    })
  ];

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    bot = lib.mkOption {
      type = lib.types.raw;
      default = null;
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
