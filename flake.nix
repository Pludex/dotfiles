{
  description = "PBCDev nix configuration for nixos and Home Manager";

  nixConfig = {
    extra-substituters = [
      "https://pbcdev.cachix.org"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://niri-epireyn.cachix.org"
      # "https://niri.cachix.org"
      "https://nyx-cache.chaotic.cx"
    ];

    extra-trusted-public-keys = [
      "pbcdev.cachix.org-1:iZbrMY/10HM5BQPXeIIHkGoDc4boLuSZYiZuPhIn9P8="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri-epireyn.cachix.org-1:tlVyFN7CtsDT+ZcLPS+ekFWeT1X6X4OqvWqbBMyIzFA="
      # "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
    ];
    substitute = true;
    allow-unfree = true;
    auto-optimise-store = true;
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      builder = import ./builder {
        extraModules = {
          home = [ ];

          nixos = with inputs; [
            chaotic.nixosModules.default
          ];

          nixvim = [ ];
        };

        extraOverlays = with inputs; [
          chaotic.overlays.default
          vscode-extensions.overlays.default
          nix-firefox-addons.overlays.default
          nur.overlays.default
          treesitter-kanata.overlays.default
          obsidian-extensions.overlays.default
        ];

        nixpkgsConfig = {
          allowUnfree = true;
          allowBroken = true;
          problems.handlers = {
            zfs.broken = "ignore";
          };
        };

        inherit inputs;
      };
    in
    (flake-parts.lib.mkFlake { inherit inputs; }

      {
        systems = [ "x86_64-linux" ];
        imports = [
          inputs.treefmt-nix.flakeModule
          ./modules/flake/nixvimConfigurations.nix
        ];

        perSystem =
          { system, ... }:
          let
            pkgs = builder.mkPkgs { inherit system; };
          in
          {
            _module.args.pkgs = pkgs;
            treefmt.config = {
              projectRootFile = "flake.nix";
              programs = {
                nixfmt.enable = true;
                prettier.enable = true;
                shfmt.enable = true;
                # ruff.enable = true;
              };
            };

            nixvimConfigurations = {
              ecode = builder.mkNixvim {
                profile = "ecode";
                inherit system;
              };
            };

            legacyPackages = pkgs;
            packages = pkgs.myPkgs;

            # devShells.default = import ./devshell.nix { inherit pkgs; };
          };

        flake = {
          homeConfigurations = {
            default = builder.mkHome {
              name = "default";
              profile = "desktop";
              desktop = "niri";
              system = "x86_64-linux";
            };

            "pbcdev@dp7530" = builder.mkHome {
              name = "pbcdev@dp7530";
              profile = "desktop";
              desktop = "niri";
              system = "x86_64-linux";
            };
          };

          nixosConfigurations = {
            default = builder.mkNixos {
              name = "default";
              profile = "desktop";
              desktop = "niri";
              host = "dp7530";
              system = "x86_64-linux";
            };

            dp7530 = builder.mkNixos {
              name = "dp7530";
              profile = "desktop";
              desktop = "niri";
              host = "dp7530";
              system = "x86_64-linux";
            };

            nixos-live = builder.mkNixos {
              name = "live";
              profile = "live";
              desktop = "niri";
              host = "live";
              system = "x86_64-linux";
            };
          };

          inherit (builder) mkPkgs;
        };
      }
    )
    // {
      # disguised nixpkgs
      __functor =
        self: args:
        builder.mkPkgs {
          system = args.localSystem or builtins.currentSystem;
          extraArgsNixpkgs = args;
        };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";

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
      url = "github:pbcdev210/schemes";
      flake = false;
    };

    # niri

    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:epireyn/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    waycal = {
      url = "github:forrestknight/waycal";
      flake = false;
    };

    nsticky = {
      url = "github:lonerOrz/nsticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma

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
      url = "github:pbcdev210/treesitter-kanata";
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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # vm

    nix-virt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # miscelaneous

    nix-flatpak.url = "github:gmodena/nix-flatpak/v0.7.0";
    claude-desktop.url = "github:Reginleif88/claude-cowork-nix";
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sunix = {
      url = "github:gvolpe/sunix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sklauncher-appimage-x86_64-linux = {
      url = "https://github.com/sklauncher/binaries/releases/download/v4.0.47/SKlauncher-4.0.47-x86_64.AppImage";
      flake = false;
    };

    wps-fonts = {
      url = "github:ferion11/ttf-wps-fonts";
      flake = false;
    };

    flake-compat.url = "github:edolstra/flake-compat";
  };
}
