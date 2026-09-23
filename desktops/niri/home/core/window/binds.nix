{
  programs.niri.settings.binds = {
    "Mod+S".action.close-window = { };
    "Mod+Q".action.close-window = { };

    "Mod+R".action.switch-preset-column-width = { };
    "Mod+W".action.toggle-column-tabbed-display = { };

    "Mod+Left".action.focus-column-left = { };
    "Mod+Down".action.focus-window-down = { };
    "Mod+Up".action.focus-window-up = { };
    "Mod+Right".action.focus-column-right = { };

    "Mod+H".action.focus-column-left = { };
    #"Mod+J".action.focus-window-down = { };
    #"Mod+K".action.focus-window-up = { };
    "Mod+L".action.focus-column-right = { };

    "Mod+Shift+Left".action.move-column-left = { };
    "Mod+Shift+Down".action.move-window-down-or-to-workspace-down = { };
    "Mod+Shift+Up".action.move-window-up-or-to-workspace-up = { };
    "Mod+Shift+Right".action.move-column-right = { };

    "Mod+Shift+H".action.move-column-left = { };
    "Mod+Shift+J".action.move-window-down-or-to-workspace-down = { };
    "Mod+Shift+K".action.move-window-up-or-to-workspace-up = { };
    "Mod+Shift+L".action.move-column-right = { };

    "Mod+J".action.focus-window-or-workspace-down = { };
    "Mod+K".action.focus-window-or-workspace-up = { };

    "Mod+Ctrl+J".action.move-window-down-or-to-workspace-down = { };
    "Mod+Ctrl+K".action.move-window-up-or-to-workspace-up = { };

    "Mod+C".action.toggle-window-floating = { };
    "Mod+Shift+C".action.switch-focus-between-floating-and-tiling = { };

    "Mod+Shift+Page_Down".action.move-workspace-down = { };
    "Mod+Shift+Page_Up".action.move-workspace-up = { };

    "Mod+WheelScrollRight".action.focus-column-right = { };
    "Mod+WheelScrollLeft".action.focus-column-left = { };
    "Mod+Ctrl+WheelScrollRight".action.move-column-right = { };
    "Mod+Ctrl+WheelScrollLeft".action.move-column-left = { };
  };
}
