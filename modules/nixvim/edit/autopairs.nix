{
  plugins.nvim-autopairs = {
    enable = true;
    settings = {
      check_ts = true;
      ts_config = {
        lua = [
          "string"
          "source"
        ];
        javascript = [ "template_string" ];
      };

      map_cr = true;

      # fast_wrap = {
      #   map = "<A-e>";
      #   chars = [ "{" "[" "(" "\"" "'" ];
      #   pattern = [ "[=[--[[%w%%%'%\"%.%_%.%-%+] ]*]" ];
      #   end_key = "$";
      #   keys = "qwertyuiopzxcvbnmasdfghjkl";
      #   check_comma = true;
      #   highlight = "Search";
      #   highlight_grey = "Comment";
      # };
    };
  };

  plugins.cmp.settings.event = [
    {
      name = "confirm_done";
      user_data = ''
        local cmp_autopairs = require('nvim-autopairs.completion.cmp')
        local cmp = require('cmp')
        cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
      '';
    }
  ];
}
