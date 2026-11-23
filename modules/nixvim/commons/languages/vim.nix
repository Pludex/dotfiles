{
  plugins.cmp.cmdline = {
    "/" = {
      mapping = {
        __raw = "cmp.mapping.preset.cmdline()";
      };
      sources = [
        { name = "buffer"; }
      ];
    };

    ":" = {
      mapping = {
        __raw = "cmp.mapping.preset.cmdline()";
      };
      sources = [
        { name = "path"; }
        { name = "cmdline"; }
      ];
      matching = {
        disallow_symbol_nonprefix_matching = false;
      };
    };
  };

  plugins.blink-cmp.settings = {
    cmdline = {
      enabled = true;

      keymap = {
        preset = "cmdline";
        # "<Tab>" = [ "show" "accept" ];
        # "<C-n>" = [ "select_next" ];
        # "<C-p>" = [ "select_prev" ];
      };

      completion = {
        menu.auto_show = true;

        list.selection.preselect = false;
      };

      sources.__raw = ''
        function()
          local type = vim.fn.getcmdtype()
          if type == "/" or type == "?" then
            return { "buffer" }
          end
          if type == ":" then
            return { "cmdline" }
          end
          return {}
        end
      '';
    };
  };
}
