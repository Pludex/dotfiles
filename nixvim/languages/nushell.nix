{
  plugins.lsp.servers.nushell = {
    enable = true;
  };

  plugins.conform-nvim.settings.formatters_by_ft = {
    nu = [ "nu_fmt" ];
  };

  plugins.treesitter.settings.ensure_installed = [
    "nu"
  ];
}
