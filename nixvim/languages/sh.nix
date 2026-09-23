{
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
}
