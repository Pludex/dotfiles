{
  plugins.lsp.servers.cssls = {
    enable = true;
  };

  plugins.treesitter.settings.ensure_installed = [
    "css"
    "scss"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    css = [ "prettier" ];
    scss = [ "prettier" ];
    less = [ "prettier" ];
  };
}
