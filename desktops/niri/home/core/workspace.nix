{
  programs.niri.settings.workspaces = {
    "01-entertainment".name = "entertainment";
    "02-study".name = "study";
    "03-code".name = "code";
    "04-society".name = "society";
    "05-temporary".name = "temporary";
  };

  programs.niri.settings.binds = {
    "Mod+1".action.focus-workspace = "entertainment";
    "Mod+2".action.focus-workspace = "study";
    "Mod+3".action.focus-workspace = "code";
    "Mod+4".action.focus-workspace = "society";
    "Mod+5".action.focus-workspace = "temporary";

    "Mod+Shift+1".action.move-column-to-workspace = "entertainment";
    "Mod+Shift+2".action.move-column-to-workspace = "study";
    "Mod+Shift+3".action.move-column-to-workspace = "code";
    "Mod+Shift+4".action.move-column-to-workspace = "society";
    "Mod+Shift+5".action.move-column-to-workspace = "temporary";
  };
}
