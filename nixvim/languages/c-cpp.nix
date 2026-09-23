{
  lsp.servers.clangd = {
    enable = true;
    config = {
      cmd = [
        "clangd"
        "--background-index"
        "--clang-tidy"
        "--header-insertion=iwyu"
        "--completion-style=detailed"
      ];
      filetypes = [
        "h"
        "hpp"
        "c"
        "cpp"
        "cxx"
        "cc"
      ];
    };
  };

  plugins.treesitter.settings.ensure_installed = [
    "cpp"
    "c"
  ];
  plugins.conform-nvim.settings.formatters_by_ft = {
    h = [ "clang-format" ];
    hpp = [ "clang-format" ];
    c = [ "clang-format" ];
    cpp = [ "clang-format" ];
    cxx = [ "clang-format" ];
    cc = [ "clang-format" ];
  };
}
