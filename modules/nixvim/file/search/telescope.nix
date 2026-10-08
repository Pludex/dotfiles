let
  mkSplit = cmd: {
    __raw = ''
      function(prompt_bufnr)
        local actions = require("telescope.actions")
        local state = require("telescope.actions.state")
        local entry = state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not entry then return end

        vim.cmd("${cmd}")
        if entry.bufnr and not (entry.path or entry.filename) then
          vim.api.nvim_set_current_buf(entry.bufnr)
        else
          vim.cmd.edit(vim.fn.fnameescape(entry.path or entry.filename))
        end
        if entry.lnum then
          pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, math.max((entry.col or 1) - 1, 0) })
        end
      end
    '';
  };

  splitMappings = {
    "<C-h>" = mkSplit "leftabove vsplit";
    "<C-j>" = mkSplit "rightbelow split";
    "<C-k>" = mkSplit "leftabove split";
    "<C-l>" = mkSplit "rightbelow vsplit";
  };
in
{
  plugins.web-devicons.enable = true;

  plugins.telescope = {
    enable = true;
    settings = {
      defaults = {
        prompt_prefix = "  ";
        selection_caret = " ";
        entry_prefix = "  ";
        path_display = [ "filename_first" ];
        layout_strategy = "horizontal";
        sorting_strategy = "descending";
        color_devicons = true;
        dynamic_preview_title = true;
        results_title = false;
        winblend = 8;

        borderchars = [
          "─"
          "│"
          "─"
          "│"
          "╭"
          "╮"
          "╯"
          "╰"
        ];

        layout_config = {
          prompt_position = "bottom";
          width = 0.9;
          height = 0.9;
          preview_width = 0.55;
        };

        mappings = {
          n = {
            "q" = "close";
            "<leader>ff" = "close";
            "<leader>fb" = "close";
          }
          // splitMappings;

          i = {
            "<C-BS>".__raw = ''
              function(prompt_bufnr)
                vim.api.nvim_feedkeys(
                  vim.api.nvim_replace_termcodes("<C-w>", true, false, true),
                  "i",
                  false
                )
              end
            '';
          }
          // splitMappings;
        };
      };
    };

    extensions = {
      zf-native = {
        enable = true;
        settings = {
          file.enable = true;
          generic.enable = false;
        };
      };

      live-grep-args = {
        enable = true;
        settings.auto_quoting = true;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ff";
      action = "<CMD>Telescope find_files<CR>";
      options = {
        silent = true;
        desc = "Telescope find files";
      };
    }
    {
      mode = "n";
      key = "<leader>fb";
      action = "<CMD>Telescope buffers<CR>";
      options = {
        silent = true;
        desc = "Telescope open buffers";
      };
    }
    {
      mode = "n";
      key = "<leader>fg";
      action.__raw = ''
        function()
          require('telescope').extensions.live_grep_args.live_grep_args()
        end
      '';
      options.desc = "Live grep (args)";
    }
  ];
}
