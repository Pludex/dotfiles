{
  plugins.lsp.servers.fsautocomplete = {
    enable = true;
  };

  plugins.conform-nvim.settings.formatters_by_ft = {
    fs = [ "fsharp" ];
  };

  plugins.treesitter.settings.ensure_installed = [ "fsharp" ];
}
