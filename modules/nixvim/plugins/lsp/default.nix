{
  plugins.lsp = {
    enable = true;

    keymaps = {
      lspBuf = {
        "gd" = "definition";
        "gD" = "declaration";
        "gi" = "implementation";
        "gt" = "type_definition";
        "K" = "hover";
        "<F2>" = "rename";
        "<F4>" = "code_action";
      };

      diagnostic = {
        "[d" = "goto_prev";
        "]d" = "goto_next";
      };
    };
  };
}
