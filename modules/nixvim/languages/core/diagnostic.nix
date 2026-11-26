{
  diagnostic = {
    settings = {
      update_in_insert = true;
      float = {
        border = "rounded";
        source = "always";
      };
      severity_sort = true;
    };
  };

  plugins.lsp-lines = {
    enable = true;
  };
  diagnostic.settings = {
    virtual_text = false;
    virtual_lines = true;
  };
}
