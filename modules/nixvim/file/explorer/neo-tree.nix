{ base, ... }:
{
  plugins.neo-tree = {
    enable = true;

    settings = {
      close_if_last_window = true;
      async_directory_scan = "always";

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
        popupBorderStyle = "rounded";

        popup = {
          title = "";
          title_pos = "none";

          #border = base.glyphs.border;
          border = "single";

          position = {
            row = "50%";
            col = "50%";
          };

          size = {
            width = "90%";
            height = "90%";
          };
        };
        mappings = {
          "l" = "open";
          "h" = "close_node";
        };
      };

      default_component_configs = {
        git_status = {
          symbols = {
            added = base.glyphs.git.diff.added;
            conflict = base.glyphs.git.diff.conflict;
            deleted = base.glyphs.git.diff.removed;
            ignored = base.glyphs.git.diff.ignored;
            modified = base.glyphs.git.diff.modified;
            renamed = base.glyphs.git.diff.renamed;
            untracked = base.glyphs.git.diff.untracked;
          };
        };
        created.enabled = false;
        last_modified.enabled = false;
        type.enabled = false;
        symlink_target.enabled = true;
        container.enable_character_fade = true;
      };

      renderers = {
        file = [
          { __unkeyed-1 = "indent"; }
          { __unkeyed-1 = "icon"; }
          {
            __unkeyed-1 = "name";
            useGitStatusColors = true;
          }
        ];
      };
    };
  };

  plugins.neo-tree.settings.event_handlers = [
    {
      event = "file_opened";
      handler.__raw = ''
        function(file_path)
          require("neo-tree.command").execute({ action = "close" })
        end
      '';
    }
  ];

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "<CMD>Neotree toggle<CR>";
      options = {
        silent = true;
        desc = "Toggle Neo-tree sidebar";
      };
    }
  ];

  plugins.lualine.settings.extensions = [ "neo-tree" ];
}
