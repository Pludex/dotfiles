{ base, ... }:
{
  plugins.lualine = {
    enable = true;

    settings = {
      options = {
        theme = "auto";

        icons_enabled = true;

        component_separators = {
          left = "";
          right = "";
        };
        section_separators = {
          left = "";
          right = "";
        };

        globalstatus = true;

        refresh = {
          statusline = 1000;
          tabline = 1000;
          winbar = 1000;
        };
      };

      sections = {

        lualine_a = [ "mode" ];

        lualine_b = [
          {
            __unkeyed-1 = "branch";
            icon = base.glyphs.git.branch.icon;
          }
        ];

        lualine_c = [
          {
            __unkeyed-1 = "diagnostics";
            sources = [ "nvim_diagnostic" ];
            symbols = {
              error = base.glyphs.level.error;
              warn = base.glyphs.level.warn;
              info = base.glyphs.level.info;
              hint = base.glyphs.level.hint;
            };
          }
        ];

        lualine_x = [
          "filetype"
        ];

        lualine_y = [
          "progress"
        ];
        lualine_z = [ "location" ];
      };

      tabline = {
        lualine_a = [
          {
            __unkeyed-1 = "filename";
            file_status = true;
            path = 0;

            symbols = {
              modified = base.glyphs.file.modified;
              readonly = base.glyphs.file.modified;
              unnamed = base.glyphs.file.unnamed;
              newfile = base.glyphs.file.newfile;
            };
          }

        ];

        lualine_b = [
          {
            __unkeyed-1 = "diff";
            symbols = {
              added = base.glyphs.git.diff.added;
              modified = base.glyphs.git.diff.modified;
              removed = base.glyphs.git.diff.removed;
            };
          }
        ];

        lualine_c = [
          "encoding"
          {
            __unkeyed-1 = "navic";
            color_correction = "dynamic";
            navic_opts = null;
          }
        ];

        lualine_x = [ ];
        lualine_y = [
          {
            __unkeyed-1 = "lsp_status";
            icon = base.glyphs.lsp.icon;

            fmt.__raw = ''
              function()
                local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if next(clients) == nil then
                  return '[No LSP]'
                end
                local client_names = {}
                for _, client in ipairs(clients) do
                  table.insert(client_names, client.name)
                end
                return table.concat(client_names, ', ')
              end
            '';
          }
        ];

        lualine_z = [
          {
            __unkeyed-1 = "datetime";
            style = "%H:%M";
            icon = " ";
          }
        ];
      };
    };
  };

  extraConfigLua = ''
    vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'TabLineFill', { bg = 'NONE' })
  '';
}
