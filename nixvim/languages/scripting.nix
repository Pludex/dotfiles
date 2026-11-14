{
  modules.nixvim.languages = {
    kanata =
      { pkgs, ... }:
      {
        extraPlugins = [
          pkgs.myPkgs.vimPlugins.treesitter-kanata
        ];

        filetype.extension.kbd = "kanata";
        plugins.treesitter.languageRegister.kanata = "kbd";
      };

    lua =
      { inputs, ... }:
      {
        plugins.lsp.servers.lua_ls = {
          enable = true;
          extraOptions = {
            settings = {
              Lua = {
                diagnostics.globals = [ "vim" ];

                workspace = {
                  library = [
                    "\${3rd}/luv/library"
                    "${inputs.wezterm-types}/lua/wezterm/types"
                  ];
                  checkThirdParty = false;
                };
              };
            };
          };
        };

        plugins.treesitter.settings.ensure_installed = [ "lua" ];
        plugins.conform-nvim.settings.formatters_by_ft = {
          lua = [ "stylua" ];
        };
      };

    nix =
      { base, pkgs, ... }:
      {
        plugins.lsp.servers.nixd = {
          enable = true;
          settings.nixd = {
            formatting.command = [ "nixfmt" ];
            options = {
              nixpkgs.expr = "import <nixpkgs> { }";
              nixos.expr = ''(builtins.getFlake "path:${base.abs.dotfiles}").nixosConfigurations.default.options'';
              home_manager.expr = ''(builtins.getFlake "path:${base.abs.dotfiles}").homeConfigurations.default.options'';
              nixvim.expr = ''(builtins.getFlake "path:${base.abs.dotfiles}").${pkgs.stdenv.system}.nixvimConfiguration.options'';
            };
          };
        };

        plugins.conform-nvim.settings.formatters_by_ft = {
          nix = [ "nixfmt" ];
        };

        plugins.treesitter.settings.ensure_installed = [ "nix" ];

        extraPackages = [ pkgs.nixfmt ];
      };

    nushell = {
      plugins.lsp.servers.nushell = {
        enable = true;
      };

      plugins.conform-nvim.settings.formatters_by_ft = {
        nu = [ "nu_fmt" ];
      };

      plugins.treesitter.settings.ensure_installed = [
        "nu"
      ];
    };

    python = {
      plugins.lsp.servers.pyright = {
        enable = true;

        settings = {
          typeCheckingMode = "basic";

          autoSearchPaths = true;
          useLibraryCodeForTypes = true;

          diagnosticMode = "workspace";
        };
      };

      plugins.conform-nvim.settings.formatters_by_ft = {
        py = [ "ruff_format" ];
      };

      plugins.treesitter.settings.ensure_installed = [ "python" ];
    };

    sh = {
      plugins.lsp.servers.bashls = {
        enable = true;
      };

      plugins.treesitter.settings.ensure_installed = [
        "bash"
      ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        sh = [ "shfmt" ];
        bash = [ "bash" ];
        zsh = [ "shfmt" ];
      };
    };
  };
}
