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
    coding = {
      host = "dp7530";
    };

    leetcode = {
      host = "dp7530";
    };
  };

  systems = [
    "x86_64-linux"
  ];

  nixpkgs.inputOverlays = with inputs; [
    chaotic.overlays.default
    vscode-extensions.overlays.default
    nix-firefox-addons.overlays.default
    nur.overlays.default
    obsidian-extensions.overlays.default
    emacs-overlays.overlays.default
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
    android_sdk.accept_license = true;

    permittedInsecurePackages = [
      "electron-39.8.10"
      "electron-41.10.6"
    ];

    problems.handlers = {
      zfs.broken = "ignore";
      "gtk+".broken = "warn";
    };
  };

  perSystem = _: {
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
    ./pkgs
    ./profiles
    ./hosts
    ./features
    ./lib
    ./base.nix
    ./devshells.nix

    inputs.treefmt-nix.flakeModule
  ];
}
