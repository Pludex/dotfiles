{ base, pkgs, ... }: {
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
}
