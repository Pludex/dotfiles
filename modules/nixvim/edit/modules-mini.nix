{
  plugins.mini.modules = {
    move = {
      mappings = {
        left = "<C-h>";
        right = "<C-l>";
        down = "<C-j>";
        up = "<C-k>";

        line_left = "<C-h>";
        line_right = "<C-l>";
        line_down = "<C-j>";
        line_up = "<C-k>";
      };
    };

    pairs = {
      modes = {
        insert = true;
        command = true;
        terminal = true;
      };
    };

    comment = {
      mappings = {
        comment = "<leader>/";
        comment_line = "<leader>/";
        comment_visual = "<leader>/";
        textobject = "<leader>/";
      };
    };

    indentscope = {
      symbol = "┆";
      draw = {
        delay = 0;
      };
    };
  };
}
