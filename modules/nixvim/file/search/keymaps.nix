{
  keymaps = [
    {
      mode = "n";
      key = "<A-f>";
      action = "<CMD>bnext<CR>";
      options = {
        silent = true;
        desc = "Next buffer";
      };
    }

    {
      mode = "n";
      key = "<A-d>";
      action = "<CMD>bprevious<CR>";
      options = {
        silent = true;
        desc = "Previous buffer";
      };
    }

    {
      mode = "n";
      key = "<A-s>";
      action = "<CMD>bdelete<CR>";
      options = {
        silent = true;
        desc = "Close current buffer/tab";
      };
    }

  ];
}
