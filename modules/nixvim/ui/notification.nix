{ base, ... }:
{
  plugins.snacks.settings.notifier = {
    enabled = true;

    timeout = 3000;

    width = {
      min = 40;
      max = 0.4;
    };
    height = {
      min = 1;
      max = 0.6;
    };

    margin = {
      top = 0;
      right = 1;
      bottom = 0;
    };
    padding = true;
    gap = 0;

    sort = [
      "level"
      "added"
    ];

    level.__raw = "vim.log.levels.TRACE";

    icons = {
      inherit (base.glyphs.level)
        error
        warn
        info
        debug
        trace
        ;
    };

    keep.__raw = ''
      function(notif)
        return vim.fn.getcmdpos() > 0
      end
    '';

    style = "compact";
    top_down = true;

    date_format = "%R";
    more_format = " ↓ %d lines ";
    refresh = 50;

    filter.__raw = ''
      function(notif)
        return true
      end
    '';
  };

  extraConfigLua = ''
    vim.notify = require("snacks").notifier.notify
  '';
}
