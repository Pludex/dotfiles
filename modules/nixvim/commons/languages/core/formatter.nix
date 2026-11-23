let
  writeFormat = ''
    function()
      require("conform").format({ async = true }, function(err)
        if not err then
          vim.cmd("silent! write")
        end
      end)
    end
  '';
in
{
  plugins.conform-nvim = {
    enable = true;

    settings = {
      default_format_opts = {
        lsp_format = "fallback";
        timeout_ms = 500;
      };
    };
  };

  userCommands = {
    Fm = {
      desc = "Format buffer or selection";
      range = true;
      command.__raw = ''
        function(args)
          local range = nil
          if args.range > 0 then
            local last = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
            range = { start = { args.line1, 0 }, ["end"] = { args.line2, #last } }
          end
          require("conform").format({ async = true, range = range })
        end
      '';
    };

    Wf = {
      desc = "Format then write";
      command.__raw = writeFormat;
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>q";
      action.__raw = writeFormat;
      options = {
        silent = true;
        desc = "Format and write";
      };
    }
  ];

  extraConfigVim = ''
    cnoreabbrev <expr> fm getcmdtype() == ":" && getcmdline() == "fm" ? "Fm" : "fm"
    cnoreabbrev <expr> wf getcmdtype() == ":" && getcmdline() == "wf" ? "Wf" : "wf"
  '';
}
