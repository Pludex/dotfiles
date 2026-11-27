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
      host = "dp7530";
    };

    dp7530 = {
      profile = "desktop";
      host = "dp7530";
    };

    nixos-live = {
      profile = "live";
      host = "live";
    };

    ci = {
      profile = "desktop";
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
    llm-agent.overlays.shared-nixpkgs
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

  roleGroups = [
    "graphical"
    "interactive"
    "headless"
    "physical"
    "portable"
    "ephemeral"
    "container"
  ];

  roles = {
    container.groups = [
      "headless"
      "container"
    ];
    desktop.groups = [
      "graphical"
      "interactive"
      "physical"
    ];
    laptop.groups = [
      "graphical"
      "interactive"
      "physical"
      "portable"
    ];
    live.groups = [
      "graphical"
      "interactive"
      "physical"
      "ephemeral"
    ];
    server.groups = [
      "headless"
      "physical"
    ];
  };

  flake.lib = inputs.nixpkgs.lib;

  imports = [
    ./pkgs
    ./profiles
    ./desktops
    ./hosts
    ./features
    ./lib
    ./modules
    ./settings.nix
    ./devshells.nix

    ./home/apps.nix
    ./home/services
    ./home/develop.nix
    ./home/packages.nix
    ./home/programs

    ./nixos/services
    ./nixos/apps.nix
    ./nixos/virtualisation.nix

    inputs.treefmt-nix.flakeModule
  ];
}
