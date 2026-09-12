{
  plugins.lsp.servers.lemminx = {
    enable = true;
  };

  plugins.treesitter.settings.ensure_installed = [ "xml" ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    xml = [ "xmlformatter" ];
  };
}
