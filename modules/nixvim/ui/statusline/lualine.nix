{ ... }:
let
  lspNames = ''
    function()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      if next(clients) == nil then
        return "No LSP"
      end
      local names = {}
      for _, client in ipairs(clients) do
        table.insert(names, client.name)
      end
      return table.concat(names, ", ")
    end
  '';

  recording = ''
    function()
      local reg = vim.fn.reg_recording()
      return reg == "" and "" or "recording @" .. reg
    end
  '';

  hasRecording = ''
    function()
      return vim.fn.reg_recording() ~= ""
    end
  '';

  notUtf8 = ''
    function()
      return vim.bo.fileencoding ~= "" and vim.bo.fileencoding ~= "utf-8"
    end
  '';

  wide = ''
    function()
      return vim.o.columns > 100
    end
  '';
in
{
  plugins.lualine = {
    enable = true;

    settings = {
      options = {
        theme = "auto";
        icons_enabled = true;
        globalstatus = true;

        component_separators = {
          left = "";
          right = "";
        };
        section_separators = {
          left = "";
          right = "";
        };

        disabled_filetypes = {
          statusline = [
            "dashboard"
            "alpha"
            "starter"
          ];
          winbar = [
            "dashboard"
            "alpha"
            "starter"
            "neo-tree"
            "oil"
            "help"
            "qf"
          ];
        };

        refresh = {
          statusline = 500;
          winbar = 1000;
        };
      };

      extensions = [
        "quickfix"
        "man"
      ];

      sections = {
        lualine_a = [
          {
            __unkeyed-1 = "mode";
            icon = "";
          }
        ];

        lualine_b = [
          "branch"
          {
            __unkeyed-1 = "diff";
            symbols = {
              added = " ";
              removed = " ";
              ignored = " ";
              modified = " ";
              renamed = " ";
              untracked = "󰰧 ";
              conflict = "󰰰 ";

            };
          }
        ];

        lualine_c = [
          {
            __unkeyed-1 = "diagnostics";
            sources = [ "nvim_diagnostic" ];
            symbols = {
              error = " ";
              warn = " ";
              info = "󰋽 ";
              hint = " ";
              debug = " ";
              trace = "[Trace]";
            };
          }
          {
            __unkeyed-1.__raw = recording;
            icon = "";
            cond.__raw = hasRecording;
            color = {
              fg = "#ff6c6b";
              gui = "bold";
            };
          }
          "searchcount"
          "selectioncount"
        ];

        lualine_x = [
          {
            __unkeyed-1.__raw = lspNames;
            icon = " ";
            cond.__raw = wide;
          }
          {
            __unkeyed-1 = "encoding";
            cond.__raw = notUtf8;
          }
          {
            __unkeyed-1 = "fileformat";
            symbols = {
              unix = " ";
              dos = " ";
              mac = "";
            };
          }
        ];

        lualine_y = [
          {
            __unkeyed-1 = "filetype";
            colored = true;
            icon_only = false;
            icon.align = "left";
          }
          "progress"
        ];

        lualine_z = [
          {
            __unkeyed-1 = "location";
          }
        ];
      };

      winbar = {
        lualine_c = [
          {
            __unkeyed-1 = "filename";
            file_status = true;
            path = 1;
            symbols = {
              readonly = " ";
              modified = " ";
              newfile = " ";
              unnamed = "[No Name]";
            };
          }
          {
            __unkeyed-1 = "navic";
            color_correction = "dynamic";
            navic_opts = null;
          }
        ];
      };

      inactive_winbar = {
        lualine_c = [
          {
            __unkeyed-1 = "filename";
            path = 1;
          }
        ];
      };
    };
  };

  extraConfigLua = ''
    for _, group in ipairs({ "StatusLine", "StatusLineNC", "WinBar", "WinBarNC" }) do
      vim.api.nvim_set_hl(0, group, { bg = "NONE" })
    end
  '';
}
