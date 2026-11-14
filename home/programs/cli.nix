{
  modules.home.programs = {
    bat = {
      programs.bat = {
        enable = true;

        config = {
          # theme = "TwoDark";
          style = "numbers,changes,header";
          pager = "less -FR";
          italic-text = "always";
        };
      };
      stylix.targets.bat.enable = true;
    };

    btop = {
      programs.btop = {
        enable = true;
      };

      stylix.targets.btop.enable = true;
    };

    cava = {
      programs.cava = {
        enable = true;
      };

      stylix.targets.cava.enable = true;
    };

    direnv = {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;

        config = {
          load_dotenv = true;
          hide_env_diff = true;
        };
      };
    };

    eza = {
      programs.eza = {
        enable = true;
        icons = "auto";
        colors = "auto";
      };
    };

    fd = {
      programs.fd = {
        enable = true;
        hidden = true;
      };
    };

    mpv =
      { pkgs, ... }:
      {
        programs.mpv = {
          enable = true;

          scripts = with pkgs.mpvScripts; [
            uosc
            thumbfast
            mpris
          ];

          config = {
            slang = "vie,vi,eng,en";
            alang = "jpn,ja,eng,en";

            hwdec = "auto-safe";

            volume = 80;
            volume-max = 150;

            save-position-on-quit = true;

            osc = "no";
            osd-bar = "no";
            border = "no";
            cursor-autohide = 400;
          };
        };
      };

    nh =
      { base, ... }:
      {
        programs.nh = {
          enable = true;

          flake = "${base.abs.dotfiles}";
        };
        home.sessionVariables = {
          NH_HOME_FLAKE = "${base.abs.dotfiles}";
        };
      };

    ripgrep = {
      programs.ripgrep = {
        enable = true;
      };
    };

    sunix =
      {
        pkgs,
        base,
        inputs,
        config,
        osConfig,
        ...
      }:
      {
        imports = with inputs; [
          sunix.homeModules.default
        ];

        programs.sunix = {
          enable = true;

          settings = {
            dixBinary = "${pkgs.dix}/bin/dix";
            flakeDir = base.abs.dotfiles;
            homeFlake = config.name;
            nixosFlake = osConfig.name;
            styleCss = null;
            showDemo = false;
          };
        };
      };

    yazi = {
      programs.yazi = {
        enable = true;
      };

      stylix.targets.yazi.enable = true;
    };

    superfile = ./superfile.nix;
    statix = ./statix;
  };
}
