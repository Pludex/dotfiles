{
  base,
  pkgs,
  lib,
  config,
  meta,
  ...
}:
let
  inherit (base) libx;
  bot = libx.tryOr (base.botOf meta.name) null;

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
    })
  ];

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    bot = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      default = bot;
    };
  };

  imports = [
    ./keyboard
    ./audio.nix
    ./bluetooth.nix
    ./networking.nix
    ./nix-config.nix
    ./security.nix
    ./shell.nix
    ./sops.nix
    ./users.nix
    ./xdg.nix
    bot.modules.nixos or { }
  ];
}
