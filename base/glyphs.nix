{
  extraBase.glyphs = {
    nix = {
      logo = " ";
    };

    git = {
      logo = "󰊢 ";
      commit = " ";

      staged = "● ";
      diff = {
        added = " ";
        removed = " ";
        ignored = " ";
        modified = " ";
        renamed = " ";
        untracked = "󰰧 ";
        conflict = "󰰰 ";
      };

      branch = {
        icon = " ";
      };
    };

    level = {
      error = " ";
      warn = " ";
      info = "󰋽 ";
      hint = " ";
      debug = " ";
      trace = "[Trace]";
    };

    lsp = {
      icon = " ";
    };

    prompt = " ";

    border = [
      "╭"
      "─"
      "╮"
      "│"
      "╯"
      "─"
      "╰"
      "│"
    ];

    file = {
      readonly = " ";
      modified = " ";
      newfile = " ";
      unnamed = "[No Name]";
    };
  };
}
