{
  modules.nixvim.languages = {
    md = {
      plugins.lsp.servers.marksman = {
        enable = true;
      };

      plugins.conform-nvim.settings.formatters_by_ft = {
        md = [ "prettier" ];
      };

      plugins.treesitter.settings.ensure_installed = [
        "markdown"
        "markdown_inline"
      ];
    };

    mdx = {
      plugins.treesitter.settings.ensure_installed = [
        "mdx"
        "markdown"
        "markdown_inline"
      ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        mdx = [ "prettier" ];
      };
    };
  };
}
