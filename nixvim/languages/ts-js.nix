{
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
}
