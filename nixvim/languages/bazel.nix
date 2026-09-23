{
  plugins.lsp.servers.bazelrc_lsp = {
    enable = true;
    package = null;
  };

  plugins.treesitter.settings.ensure_installed = [
    "bazel"
    "starlark"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    bazel = [ "buildifier" ];
    bzl = [ "buildifier" ];
  };
}
