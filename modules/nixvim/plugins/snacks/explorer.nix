{
  plugins.snacks.settings.explorer = {
    enabled = true;

    replace_netrw = true;
    trash = true;
  };

  plugins.snacks.settings.picker.sources.explorer = {
    tree = true;
    watch = true;
    follow_file = true;

    auto_close = true;
    jump.close = true;

    diagnostics = true;
    diagnostics_open = false;
    git_status = true;
    git_untracked = false;

    hidden = true;
    ignored = true;

    formatters = {
      file.filename_only = true;
      severity.pos = "right";
    };

    matcher = {
      sort_empty = false;
      fuzzy = false;
    };

    layout = {
      preview = false;
      layout = {
        box = "vertical";
        position = "float";
        width = 0.9;
        height = 0.9;
        border = "rounded";
        __unkeyed-1 = {
          win = "input";
          height = 1;
          title = " Explorer ";
          border = "single";
        };
        __unkeyed-2 = {
          win = "list";
        };
      };
    };
  };

  keymaps = [
    {
      key = "q";
      mode = "n";
      action = "<cmd>lua require('snacks').explorer()<CR>";
      options.desc = "Toggle file explorer";
    }
  ];
}
