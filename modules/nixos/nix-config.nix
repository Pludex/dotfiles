{
  base,
  config,
  lib,
  ...
}:
let
  isContainer = config.isContainer;
  dotfiles = if isContainer then "/workspaces/dotfiles-ref" else "/workspaces/dotfiles";
in
{
  config = lib.mkMerge [
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          accept-flake-config = !isContainer;
          warn-dirty = false;
        };

        registry.nixpkgs.to = lib.mkForce {
          type = "git";
          url = "file://${dotfiles}";
        };
      };
    }

    (lib.mkIf (!isContainer) {
      nix = {
        settings = {
          auto-optimise-store = true;
          trusted-users = [ base.username ];
          trusted-substituters = lib.mkForce [
            "https://pludex.cachix.org"
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = lib.mkForce [
            "pludex.cachix.org-1:iZbrMY/10HM5BQPXeIIHkGoDc4boLuSZYiZuPhIn9P8="
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
          randomizedDelaySec = "45min";
        };
      };
    })

    (lib.mkIf isContainer {
      networking.firewall.enable = false;

      systemd = {
        globalEnvironment.NIX_REMOTE = "daemon";
        services.nix-daemon.enable = false;
        sockets.nix-daemon.enable = false;
      };

      programs.git = {
        enable = true;
        config.safe.directory = [ "*" ];
      };
    })
  ];
}
