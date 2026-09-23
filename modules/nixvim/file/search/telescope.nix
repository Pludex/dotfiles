{
  plugins.telescope = {
    enable = true;
    settings = {
      defaults = {
        path_display = [
          "filename_first"
        ];
        layout_strategy = "horizontal";
        sorting_strategy = "descending";

        layout_config = {
          prompt_position = "bottom";
          width = 0.9;
          height = 0.9;
        };

        mappings = {
          n."q" = "close";
          n."<leader>ff" = "close";
          n."<leader>fb" = "close";

          i."<C-BS>".__raw = ''
            function(prompt_bufnr)
              vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<C-w>", true, false, true),
                "i",
                false
              )
            end
          '';
        };
      };
    };

    extensions = {
      zf-native = {
        enable = true;
        settings = {
          file = {
            enable = true;
          };
          generic = {
            enable = false;
          };
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
