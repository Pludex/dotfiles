{
  plugins.lsp.servers.neocmake = {
    enable = true;
  };

  plugins.treesitter.settings.ensure_installed = [
    "cmake"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    cmake = [ "gersemi" ];
  };
}
