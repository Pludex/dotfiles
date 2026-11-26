let
  mkTrouble = key: cmd: desc: {
    mode = "n";
    inherit key;
    action = "<cmd>Trouble ${cmd}<cr>";
    options = {
      silent = true;
      inherit desc;
    };
  };

  floatWin = {
    type = "float";
    relative = "editor";
    border = "rounded";
    position = [
      0.5
      0.5
    ];
    size = {
      width = 0.6;
      height = 0.6;
    };
    zindex = 200;
    wo.winblend = 12;
  };
in
{
  plugins.web-devicons.enable = true;

  plugins.trouble = {
    enable = true;
    settings = {
      focus = true;
      auto_close = true;
      auto_preview = true;
      auto_refresh = true;
      follow = true;
      indent_guides = true;
      multiline = true;
      warn_no_results = false;
      open_no_results = true;

      win = floatWin;

      preview = {
        type = "float";
        relative = "editor";
        border = "rounded";
        title = "Preview";
        title_pos = "center";
        position = [
          0
          (-2)
        ];
        size = {
          width = 0.4;
          height = 0.35;
        };
        zindex = 200;
        wo.winblend = 12;
      };

      modes = {
        symbols = {
          focus = false;
          win = floatWin // {
            position = [
              1
              (-2)
            ];
            size = {
              width = 0.3;
              height = 0.85;
            };
          };
        };
      };

      keys = {
        "<cr>" = "jump_close";
        "<2-leftmouse>" = "jump_close";
        "o" = "jump";
      };
    };
  };

  highlight = {
    TroubleNormal.bg = "NONE";
    TroubleNormalNC.bg = "NONE";
    TroubleIndent.fg = "#45475a";
  };

  keymaps = [
    (mkTrouble "<leader>xx" "diagnostics toggle" "Workspace diagnostics")
    (mkTrouble "<leader>xb" "diagnostics toggle filter.buf=0" "Buffer diagnostics")
    (mkTrouble "<leader>xs" "symbols toggle" "Symbols")
    (mkTrouble "<leader>xr" "lsp_references toggle" "LSP references")
    (mkTrouble "<leader>xd" "lsp_definitions toggle" "LSP definitions")
    (mkTrouble "<leader>xl" "loclist toggle" "Location list")
    (mkTrouble "<leader>xq" "qflist toggle" "Quickfix list")

    {
      mode = "n";
      key = "]x";
      action.__raw = ''
        function()
          require("trouble").next({ skip_groups = true, jump = true })
        end
      '';
      options.desc = "Next Trouble item";
    }
    {
      mode = "n";
      key = "[x";
      action.__raw = ''
        function()
          require("trouble").prev({ skip_groups = true, jump = true })
        end
      '';
      options.desc = "Previous Trouble item";
    }
  ];
}
