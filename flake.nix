{
  description = "Pludex dotfiles";

  nixConfig = {
    extra-substituters = [
      "https://pludex.cachix.org"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://niri-epireyn.cachix.org"
      "https://doom-emacs-unstraightened.cachix.org"
      # "https://niri.cachix.org"
      "https://nyx-cache.chaotic.cx"
    ];

    extra-trusted-public-keys = [
      "pludex.cachix.org-1:iZbrMY/10HM5BQPXeIIHkGoDc4boLuSZYiZuPhIn9P8="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri-epireyn.cachix.org-1:tlVyFN7CtsDT+ZcLPS+ekFWeT1X6X4OqvWqbBMyIzFA="
      "doom-emacs-unstraightened.cachix.org-1:O5oOlRPnmQEvVaFyuMTmthCEooHbrg54WgSLR07tmg4="
      # "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
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

    # nixvim

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treesitter-kanata = {
      url = "github:Pludex/treesitter-kanata";
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
