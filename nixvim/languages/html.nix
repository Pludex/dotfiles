{
  plugins.lsp.servers.html = {
    enable = true;
  };

  plugins.treesitter.settings.ensure_installed = [
    "html"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    html = [ "prettier" ];
  };
}
