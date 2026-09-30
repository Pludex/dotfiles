{
  description = "Pludex dotfiles";

  nixConfig = {
    extra-substituters = [
      # Official and community
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nyx-cache.chaotic.cx"

      # Personal
      "https://pludex.cachix.org"

      # Desktop / compositor
      "https://hyprland.cachix.org"
      "https://niri-epireyn.cachix.org"
      # "https://niri.cachix.org"

      # Apps
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
      "https://doom-emacs-unstraightened.cachix.org"
    ];

    extra-trusted-public-keys = [
      # Official and community
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="

      # Personal
      "pludex.cachix.org-1:CHPuiCwe8ATtUbq20FRCTt9mCuo5ieTwqSLcpODkL/Q="

      # Desktop / compositor
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "niri-epireyn.cachix.org-1:tlVyFN7CtsDT+ZcLPS+ekFWeT1X6X4OqvWqbBMyIzFA="
      # "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="

      # Apps
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "doom-emacs-unstraightened.cachix.org-1:O5oOlRPnmQEvVaFyuMTmthCEooHbrg54WgSLR07tmg4="
    ];

    substitute = true;
    allow-unfree = true;
    auto-optimise-store = true;
  };

  outputs = inputs: ((import ./builder { inherit inputs; }).mkDotfiles { });
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat.url = "github:edolstra/flake-compat";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # system

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # home

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # theme

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    schemes = {
      url = "github:Pludex/schemes";
      flake = false;
    };

    # wm

    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:epireyn/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    MangoWM = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/hyprland/v0.55.0";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    waycal = {
      url = "github:forrestknight/waycal";
      flake = false;
    };

    waybar = {
      url = "github:Alexays/Waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nsticky = {
      url = "github:lonerOrz/nsticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    walker = {
      url = "github:abenz1267/walker";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins/v0.55.0";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.hyprland.follows = "hyprland";
    };

    # nixvim

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm-types = {
      url = "github:/DrKJeff16/wezterm-types";
      flake = false;
    };

    msbuild-project-tools-server = {
      url = "github:/tintoy/msbuild-project-tools-server/v0.7.0";
      flake = false;
    };

    # firefox/floorp

    nix-firefox-addons = {
      url = "github:osipog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-mods = {
      url = "github:datguypiko/Firefox-Mod-Blur";
      flake = false;
    };

    firefox-mods-2 = {
      url = "github:MrOtherGuy/firefox-csshacks";
      flake = false;
    };

    # nushell

    nushell-highlight = {
      url = "git+https://github.com/cptpiepmatz/nu-plugin-highlight?submodules=1";
      flake = false;
    };

    # ghostty

    ghostty-cursor = {
      url = "github:hced/ghostty-cursor-trails";
      flake = false;
    };

    # obsidian

    obsidian-extensions = {
      url = "github:karaolidis/nix-obsidian-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # jetbrains

    jetbrains-plugins = {
      url = "github:nix-community/nix-jetbrains-plugins";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # vm

    nix-virt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # emacs

    emacs-overlays = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };

    doom-emacs = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlays";
    };

    # miscelaneous

    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sunix = {
      url = "github:gvolpe/sunix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wps-fonts = {
      url = "github:ferion11/ttf-wps-fonts";
      flake = false;
    };
  };
}
