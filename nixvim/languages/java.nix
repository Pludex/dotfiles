{
  plugins.lsp.servers.jdtls = {
    enable = true;
  };

  plugins.treesitter.settings.ensure_installed = [ "java" ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    java = [ "google-java-format" ];
  };
}
