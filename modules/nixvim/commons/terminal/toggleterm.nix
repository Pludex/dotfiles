{
  plugins.toggleterm = {
    enable = true;
    settings = {
      open_mapping = "[[<A-Space>]]";

      direction = "float";

      start_in_insert = true;

      persist_size = true;
      float_opts = {
        border = "rounded";
        winblend = 5;
      };
    };
  };
}
