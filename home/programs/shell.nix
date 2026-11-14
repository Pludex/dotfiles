{
  modules.home.programs = {
    atuin = {
      programs.atuin = {
        enable = true;
        settings = {
          keymap_mode = "vim-normal";
          search_mode = "prefix";
          style = "compact";
        };

        flags = [ "--disable-ctrl-r" ];
      };
    };

    carapace = {
      programs.carapace = {
        enable = true;
      };
    };

    fzf = {
      programs.fzf = {
        enable = true;

        defaultCommand = "fd --type f --strip-cwd-prefix --hidden";
        fileWidget.command = "fd --type f --strip-cwd-prefix --hidden";
      };

      stylix.targets.fzf.enable = true;
    };

    nix-index =
      { inputs, ... }:
      {
        imports = with inputs; [
          nix-index-database.homeModules.default
        ];
        programs.nix-index = {
          enable = true;
        };

        programs.nix-index-database.comma.enable = true;
      };

    nix-your-shell = {
      programs.nix-your-shell = {
        enable = true;
      };
    };

    tirith = {
      programs.tirith = {
        enable = true;
      };
    };

    zoxide =
      { pkgs, base, ... }:
      let
        zoxidePaths = [
          base.abs.home
          "${base.abs.home}/.config"

          "/workspaces"
          base.abs.dotfiles
          base.abs.dotfilesBot
        ];
      in
      {
        programs.zoxide = {
          enable = true;
        };

        home.activation.seedZoxide = ''
          ${builtins.concatStringsSep "\n" (map (path: "${pkgs.zoxide}/bin/zoxide add ${path}") zoxidePaths)}
        '';
      };

    starship = ./starship.nix;

    bash = ./bash.nix;
    fish = ./fish.nix;
    nushell = ./nushell;
    zsh = ./zsh;
  };
}
