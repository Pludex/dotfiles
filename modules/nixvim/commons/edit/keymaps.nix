{
  keymaps = [
    {
      mode = "v";
      key = "<C-c>";
      action = "<CMD>lua vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('\"+y', true, false, true), 'n', false)<CR>";
      options = {
        silent = true;
        desc = "Copy selection to system clipboard";
      };
    }

    {
      mode = "n";
      key = "<C-v>";
      action = "<CMD>put +<CR>";
      options = {
        silent = true;
        desc = "Paste from system clipboard";
      };
    }

    {
      mode = "i";
      key = "<C-v>";
      action = "<CMD>lua vim.api.nvim_put({vim.fn.getreg('+')}, 'c', true, true)<CR>";
      options = {
        silent = true;
        desc = "Paste from system clipboard in insert mode";
      };
    }

    {
      mode = "v";
      key = "<C-v>";
      action = "<CMD>lua vim.api.nvim_feedkeys('d', 'x', false); vim.api.nvim_put({vim.fn.getreg('+')}, 'c', true, true)<CR>";
      options = {
        silent = true;
        desc = "Paste and replace selection";
      };
    }

    {
      mode = "v";
      key = "<C-x>";
      action = "<CMD>lua vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('\"+d', true, false, true), 'n', false)<CR>";
      options = {
        silent = true;
        desc = "Cut selection to system clipboard";
      };
    }

    {
      mode = [
        "i"
        "c"
      ];
      key = "<C-BS>";
      action = "<C-w>";
      options = {
        silent = true;
        desc = "Delete inner word with Ctrl+Backspace";
      };
    }

    {
      mode = [
        "n"
        "v"
      ];
      key = "x";
      action = ''"_x'';
      options.desc = "Delete char into black hole";
    }

    {
      mode = [
        "n"
        "v"
      ];
      key = "<leader>d";
      action = ''"_d'';
      options = {
        silent = true;
        desc = "Delete without copying to clipboard";
      };
    }

    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.silent = true;
      options.desc = "Clear search highlight";
    }

    {
      mode = [
        "i"
        "c"
      ];
      key = "<C-BS>";
      action = "<C-w>";
      options = {
        silent = true;
        desc = "Delete inner word with Ctrl+Backspace";
      };
    }

    {
      mode = [
        "n"
        "v"
      ];
      key = "x";
      action = ''"_x'';
      options.desc = "Delete char into black hole";
    }

    {
      mode = [
        "n"
        "v"
      ];
      key = "<leader>d";
      action = ''"_d'';
      options = {
        silent = true;
        desc = "Delete without copying to clipboard";
      };
    }

    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.silent = true;
      options.desc = "Clear search highlight";
    }

    {
      mode = "n";
      key = "<A-e>";
      action = "<CMD>undo<CR>";
      options = {
        silent = true;
        desc = "Undo changes safely";
      };
    }

    {
      mode = "n";
      key = "<A-r>";
      action = "<CMD>redo<CR>";
      options = {
        silent = true;
        desc = "Redo changes safely";
      };
    }
  ];
}
