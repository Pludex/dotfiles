{
  plugins.diffview = {
    enable = true;

    settings = {
      enhanced_diff_hl = true;
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<M-g>";
      action.__raw = ''
        function()
          local lib = require("diffview.lib")
          local view = lib.get_current_view()
          if view then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end
      '';
      options.desc = "Toggle Diffview";
    }
  ];
}
