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
      desktop = "mango";
      system = "x86_64-linux";
    };
  };

  nixos = {
    default = {
      profile = "desktop";
      desktop = "niri";
      host = "dp7530";
      system = "x86_64-linux";
    };

    dp7530 = {
      profile = "desktop";
      desktop = "mango";
      host = "dp7530";
      system = "x86_64-linux";
    };

    nixos-live = {
      profile = "live";
      desktop = "niri";
      host = "live";
      system = "x86_64-linux";
    };
  };

  nixvim = {
    ecode = { };
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
      "electron-41.10.6"
    ];

    problems.handlers = {
      zfs.broken = "ignore";
    };
  };

  perSystem = { base, ... }: {
    treefmt.config = {
      projectRootFile = "flake.nix";
      programs = {
        nixfmt.enable = true;
        prettier.enable = true;
        shfmt.enable = true;
        # ruff.enable = true;
      };
    };

    devShells.default = import ./devshell.nix base;
  };

  imports = [
    ./base
    ./pkgs
    ./profiles

    inputs.treefmt-nix.flakeModule
  ];
}
