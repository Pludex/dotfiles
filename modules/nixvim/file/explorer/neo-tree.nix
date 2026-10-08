let
  openSplit = below: {
    __raw = ''
      function(state)
        local old = vim.o.splitbelow
        vim.o.splitbelow = ${if below then "true" else "false"}
        require("neo-tree.sources.common.commands").open_split(state)
        vim.schedule(function() vim.o.splitbelow = old end)
      end
    '';
  };
in
{
  plugins.neo-tree = {
    enable = true;

    settings = {
      close_if_last_window = true;
      async_directory_scan = "always";
      popup_border_style = "rounded";

      filesystem = {
        filtered_items = {
          visible = true;
          hide_dotfiles = false;
          hide_gitignored = false;
        };

        follow_current_file = {
          enabled = true;
          leave_dirs_open = false;
        };

        use_libuv_file_watcher = true;
      };

      window = {
        position = "float";

        popup = {
          title.__raw = ''
            function(state)
              return " 󰙅 Explorer "
            end
          '';
          title_pos = "center";

          position = {
            row = "50%";
            col = "50%";
          };

          size = {
            width = "70%";
            height = "80%";
          };
        };

        mappings = {
          "l" = "open";
          "h" = "close_node";
          "q" = "close_window";
          "<esc>" = "close_window";
          "<space>" = "none";

          "<C-h>" = "open_leftabove_vs";
          "<C-l>" = "open_rightbelow_vs";
          "<C-j>" = openSplit true;
          "<C-k>" = openSplit false;
        };
      };

      default_component_configs = {
        indent = {
          indent_size = 2;
          padding = 1;
          with_markers = true;
          indent_marker = "│";
          last_indent_marker = "└";
          with_expanders = true;
          expander_collapsed = "├";
          expander_expanded = "├";
        };

        icon = {
          folder_closed = " ";
          folder_open = " ";
          folder_empty = "󰜌 ";
          default = " ";
        };

        modified = {
          symbol = "●";
        };

        name = {
          trailing_slash = false;
          use_git_status_colors = true;
        };

        diagnostics = {
          symbols = {
            error = " ";
            warn = " ";
            info = "󰋽 ";
            hint = " ";
            debug = " ";
            trace = "[Trace]";
          };
        };

        git_status = {
          symbols = {
            added = " ";
            removed = " ";
            ignored = " ";
            modified = " ";
            renamed = " ";
            untracked = "󰰧 ";
            conflict = "󰰰 ";
          };
        };

        created.enabled = false;
        last_modified.enabled = false;
        type.enabled = false;
        symlink_target.enabled = true;
        container.enable_character_fade = true;
      };

      renderers = {
        directory = [
          { __unkeyed-1 = "indent"; }
          { __unkeyed-1 = "icon"; }
          { __unkeyed-1 = "current_filter"; }
          {
            __unkeyed-1 = "container";
            content = [
              {
                __unkeyed-1 = "name";
                zindex = 10;
              }
              {
                __unkeyed-1 = "diagnostics";
                errors_only = true;
                zindex = 20;
                align = "right";
                hide_when_expanded = true;
              }
              {
                __unkeyed-1 = "git_status";
                zindex = 10;
                align = "right";
                hide_when_expanded = true;
              }
            ];
          }
        ];

        file = [
          { __unkeyed-1 = "indent"; }
          { __unkeyed-1 = "icon"; }
          {
            __unkeyed-1 = "container";
            content = [
              {
                __unkeyed-1 = "name";
                zindex = 10;
              }
              {
                __unkeyed-1 = "symlink_target";
                zindex = 10;
                highlight = "NeoTreeSymbolicLinkTarget";
              }
              {
                __unkeyed-1 = "modified";
                zindex = 20;
                align = "right";
              }
              {
                __unkeyed-1 = "diagnostics";
                zindex = 20;
                align = "right";
              }
              {
                __unkeyed-1 = "git_status";
                zindex = 10;
                align = "right";
              }
            ];
          }
        ];
      };

      event_handlers = [
        {
          event = "file_opened";
          handler.__raw = ''
            function()
              require("neo-tree.command").execute({ action = "close" })
            end
          '';
        }
      ];
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<CMD>Neotree toggle<CR>";
      options = {
        silent = true;
        desc = "Toggle Neo-tree";
      };
    }
  ];

  highlight = {
    NeoTreeNormal.bg = "NONE";
    NeoTreeNormalNC.bg = "NONE";
    NeoTreeFloatNormal.bg = "NONE";
    NeoTreeFloatBorder.bg = "NONE";
    NeoTreeFloatTitle.bg = "NONE";
    NeoTreeTitleBar.bg = "NONE";
  };

  plugins.lualine.settings.extensions = [ "neo-tree" ];
}
