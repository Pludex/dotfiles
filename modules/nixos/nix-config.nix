{
  base,
  config,
  lib,
  ...
}:
let
  inherit (config) isContainer;
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
          warn-dirty = false;

          extra-substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            # "https://nyx-cache.chaotic.cx"

            "https://pludex.cachix.org"

            "https://hyprland.cachix.org"
            "https://niri-epireyn.cachix.org"
            # "https://niri.cachix.org"

            "https://walker.cachix.org"
            "https://walker-git.cachix.org"
            "https://doom-emacs-unstraightened.cachix.org"
          ];

          extra-trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            # "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="

            "pludex.cachix.org-1:CHPuiCwe8ATtUbq20FRCTt9mCuo5ieTwqSLcpODkL/Q="

            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "niri-epireyn.cachix.org-1:tlVyFN7CtsDT+ZcLPS+ekFWeT1X6X4OqvWqbBMyIzFA="
            # "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="

            "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
            "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
            "doom-emacs-unstraightened.cachix.org-1:O5oOlRPnmQEvVaFyuMTmthCEooHbrg54WgSLR07tmg4="
          ];
        };

        registry.nixpkgs.to = lib.mkForce {
          type = "git";
          url = "file://${dotfiles}";
        };
      };
    }

    (lib.mkIf (!isContainer) {
      nix = {
        settings.trusted-users = [ base.username ];

        optimise.automatic = true;

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
