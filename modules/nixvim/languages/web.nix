{
  modules.nixvim.languages = {
    css = {
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
    };

    html = {
      plugins.lsp.servers.html = {
        enable = true;
      };

      plugins.treesitter.settings.ensure_installed = [
        "html"
      ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        html = [ "prettier" ];
      };
    };

    ts-js = {
      plugins.lsp.servers.ts_ls = {
        enable = true;
        settings = {
          typescript.inlayHints = {
            includeInlayEnumMemberValueHints = true;
            includeInlayFunctionLikeReturnTypeHints = true;
            includeInlayFunctionParameterTypeHints = true;
            includeInlayParameterNameHints = "all"; # "none" | "literals" | "all"
            includeInlayPropertyDeclarationTypeHints = true;
            includeInlayVariableTypeHints = true;
          };

          javascript.inlayHints = {
            includeInlayEnumMemberValueHints = true;
            includeInlayFunctionLikeReturnTypeHints = true;
            includeInlayParameterNameHints = "all";
            includeInlayVariableTypeHints = true;
          };
        };
      };

      plugins.conform-nvim.settings.formatters_by_ft = {
        javascript = [ "prettier" ];
        typescript = [ "prettier" ];
        javascriptreact = [ "prettier" ];
        typescriptreact = [ "prettier" ];
      };

      plugins.treesitter.settings.ensure_installed = [
        "javascript"
        "typescript"
      ];
    };
  };
}
