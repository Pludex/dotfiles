{ inputs, base, ... }:
{
  home = {
    default = {
      profile = "desktop";
      desktop = "niri";
      system = "x86_64-linux";
    };

    "${base.username}@dp7530" = {
      profile = "desktop";
      desktop = "hyprland";
      host = "dp7530";
    };
  };

  nixos = {
    default = {
      profile = "desktop";
      desktop = "niri";
      host = "dp7530";
    };

    dp7530 = {
      profile = "desktop";
      desktop = "hyprland";
      host = "dp7530";
    };

    nixos-live = {
      profile = "live";
      desktop = "niri";
      host = "live";
    };

    ci = {
      profile = "ci";
      desktop = "tty";
      host = "ci-runner";
    };
  };

  nixvim = {
    editor = {
      host = "dp7530";
    };

    leetcode = {
      host = "dp7530";
    };
  };

  systems = [
    "x86_64-linux"
  ];

  overlaysOfInputs = with inputs; [
    chaotic.overlays.default
    vscode-extensions.overlays.default
    nix-firefox-addons.overlays.default
    nur.overlays.default
    obsidian-extensions.overlays.default
    emacs-overlays.overlays.default
  ];

  nixpkgsConfig = {
    allowUnfree = true;
    allowBroken = true;

    permittedInsecurePackages = [
      "electron-39.8.10"
      "electron-41.10.6"
    ];

    problems.handlers = {
      zfs.broken = "ignore";
    };
  };

  perSystem = { ... }: {
    treefmt.config = {
      projectRootFile = "flake.nix";
      programs = {
        nixfmt.enable = true;
        prettier.enable = true;
        shfmt.enable = true;
        # ruff.enable = true;
      };
    };
  };

  flake.lib = inputs.nixpkgs.lib;

  imports = [
    ./base
    ./pkgs
    ./profiles
    ./hosts
    ./devshells.nix

    inputs.treefmt-nix.flakeModule
  ];
}
