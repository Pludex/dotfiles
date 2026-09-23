{
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
}
