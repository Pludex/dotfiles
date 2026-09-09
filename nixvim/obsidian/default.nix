{
  plugins.obsidian = {
    enable = true;
    settings = {
      workspaces = [
        {
          name = "main";
          path = "/workspaces/pkm";
        }
      ];

      note_id_func.__raw = ''
        function(title)
          if title ~= nil then
            return title
          else
            return tostring(os.time())
          end
        end
      '';

      completion = {
        blink_cmp = true;
        min_chars = 2;
      };

      daily_notes = {
        folder = "dailies";
        date_format = "%Y-%m-%d";
      };

      picker = {
        name = "telescope.nvim";
      };

      legacy_commands = false;
      ui = {
        enable = true;
      };
    };
  };
}
