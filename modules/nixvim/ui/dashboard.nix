{
  plugins.snacks.settings.dashboard = {
    enabled = true;
    width = 60;
    row = null;
    col = null;
    pane_gap = 4;
    autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    preset = {
      pick = null;

      keys = [
        {
          icon = " ";
          key = "f";
          desc = "Find File";
          action = ":lua Snacks.dashboard.pick('files')";
        }
        {
          icon = " ";
          key = "n";
          desc = "New File";
          action = ":ene | startinsert";
        }
        {
          icon = " ";
          key = "g";
          desc = "Find Text";
          action = ":lua Snacks.dashboard.pick('live_grep')";
        }
        {
          icon = " ";
          key = "r";
          desc = "Recent Files";
          action = ":lua Snacks.dashboard.pick('oldfiles')";
        }
        {
          icon = " ";
          key = "c";
          desc = "Config";
          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})";
        }
        {
          icon = " ";
          key = "s";
          desc = "Restore Session";
          section = "session";
        }
        {
          icon = "󰒲 ";
          key = "L";
          desc = "Lazy";
          action = ":Lazy";
          enabled.__raw = "package.loaded.lazy ~= nil";
        }
      ];

      header = ''
        ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
        ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
        ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
        ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
        ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
        ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝'';
    };

    formats = {
      icon.__raw = ''
        function(item)
          if item.file and item.icon == "file" or item.icon == "directory" then
            return Snacks.dashboard.icon(item.file, item.icon)
          end
          return { item.icon, width = 2, hl = "icon" }
        end
      '';

      footer = {
        __unkeyed-1 = "%s";
        align = "center";
      };
      header = {
        __unkeyed-1 = "%s";
        align = "center";
      };

      file.__raw = ''
        function(item, ctx)
          local fname = vim.fn.fnamemodify(item.file, ":~")
          fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
          if #fname > ctx.width then
            local dir = vim.fn.fnamemodify(fname, ":h")
            local file = vim.fn.fnamemodify(fname, ":t")
            if dir and file then
              file = file:sub(-(ctx.width - #dir - 2))
              fname = dir .. "/…" .. file
            end
          end
          local dir, file = fname:match("^(.*)/(.+)$")
          return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } } or { { fname, hl = "file" } }
        end
      '';
    };

    sections = [
      { section = "header"; }
      {
        section = "keys";
        gap = 1;
        padding = 1;
      }
      {
        pane = 2;
        icon = " ";
        title = "Recent Files";
        section = "recent_files";
        indent = 2;
        padding = 1;
      }
      {
        pane = 2;
        icon = " ";
        title = "Projects";
        section = "projects";
        indent = 2;
        padding = 1;
      }
      {
        pane = 2;
        icon = " ";
        title = "Git Status";
        section = "terminal";
        enabled.__raw = ''
          function()
            return Snacks.git.get_root() ~= nil
          end
        '';
        cmd = "git status --short --branch --renames";
        height = 5;
        padding = 1;
        ttl = 5 * 60;
        indent = 3;
      }
    ];
  };
}
