{
  plugins.gitsigns = {
    enable = true;
    settings = {
      current_line_blame = true;

      current_line_blame_opts = {
        virt_text = true;
        virt_text_pos = "eol";
        delay = 500;
      };

      signs = {
        add = {
          text = "┃";
        };
        change = {
          text = "┃";
        };
        delete = {
          text = "_";
        };
        topdelete = {
          text = "‾";
        };
        changedelete = {
          text = "~";
        };
      };
    };
  };
}
