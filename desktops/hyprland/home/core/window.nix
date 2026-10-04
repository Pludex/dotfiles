{ pkgs, config, ... }:
let
  resizePx = 30;
  colors = config.lib.stylix.colors;

  confirmExpo = ''
    function()
      hl.plugin.hyprexpo.kb_confirm()
      hl.dispatch(hl.dsp.submap("reset"))
    end
  '';
in
{
  programs.hyprland.plugins = [
    pkgs.hyprlandPlugins.hyprexpo
  ];

  programs.hyprland.settings = {
    binds = {
      "Mod+S".dsp."window.close" = true;

      # Focus window
      "Mod+H".dsp.focus.direction = "l";
      "Mod+J".dsp.focus.direction = "d";
      "Mod+K".dsp.focus.direction = "u";
      "Mod+L".dsp.focus.direction = "r";

      # Move window
      "Mod+Shift+H".dsp."window.move".direction = "l";
      "Mod+Shift+J".dsp."window.move".direction = "d";
      "Mod+Shift+K".dsp."window.move".direction = "u";
      "Mod+Shift+L".dsp."window.move".direction = "r";

      "Mod+mouse:272" = {
        dsp."window.drag" = true;
        flags.mouse = true;
      };
      "Mod+mouse:273" = {
        dsp."window.resize" = true;
        flags.mouse = true;
      };

      # Focus workspace 1-9
      "Mod+1".dsp.focus.workspace = "5";
      "Mod+2".dsp.focus.workspace = "6";
      "Mod+3".dsp.focus.workspace = "7";
      "Mod+4".dsp.focus.workspace = "8";
      "Mod+5".dsp.focus.workspace = "9";
      "Mod+6".dsp.focus.workspace = "1";
      "Mod+7".dsp.focus.workspace = "2";
      "Mod+8".dsp.focus.workspace = "3";
      "Mod+9".dsp.focus.workspace = "4";

      "Mod+Q".dsp.focus.workspace = "1";
      "Mod+W".dsp.focus.workspace = "2";
      "Mod+E".dsp.focus.workspace = "3";
      "Mod+R".dsp.focus.workspace = "4";

      # Move window to workspace 1-9
      "Mod+Shift+1".dsp."window.move".workspace = "5";
      "Mod+Shift+2".dsp."window.move".workspace = "6";
      "Mod+Shift+3".dsp."window.move".workspace = "7";
      "Mod+Shift+4".dsp."window.move".workspace = "8";
      "Mod+Shift+5".dsp."window.move".workspace = "9";
      "Mod+Shift+6".dsp."window.move".workspace = "1";
      "Mod+Shift+7".dsp."window.move".workspace = "2";
      "Mod+Shift+8".dsp."window.move".workspace = "3";
      "Mod+Shift+9".dsp."window.move".workspace = "4";

      "Mod+Shift+Q".dsp."window.move".workspace = "1";
      "Mod+Shift+W".dsp."window.move".workspace = "2";
      "Mod+Shift+E".dsp."window.move".workspace = "3";
      "Mod+Shift+R".dsp."window.move".workspace = "4";

      "Mod+C".dsp.submap = "Resize";
      "Mod+Return".dsp."window.fullscreen" = {
        mode = "fullscreen";
        action = "toggle";
      };

      "Mod+Tab".dsp.__raw = ''
        function()
          hl.plugin.hyprexpo.expo("toggle")
          hl.dispatch(hl.dsp.submap("hyprexpo"))
        end
      '';
    };

    submaps.Resize.binds = {
      "L" = {
        dsp."window.resize" = {
          x = resizePx;
          y = 0;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "H" = {
        dsp."window.resize" = {
          x = -resizePx;
          y = 0;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "K" = {
        dsp."window.resize" = {
          x = 0;
          y = -resizePx;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "J" = {
        dsp."window.resize" = {
          x = 0;
          y = resizePx;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };

      "Right" = {
        dsp."window.resize" = {
          x = resizePx;
          y = 0;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "Left" = {
        dsp."window.resize" = {
          x = -resizePx;
          y = 0;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "Up" = {
        dsp."window.resize" = {
          x = 0;
          y = -resizePx;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };
      "Down" = {
        dsp."window.resize" = {
          x = 0;
          y = resizePx;
          relative = true;
        };

        flags = {
          repeating = true;
        };
      };

      # Exit submap
      "Escape".dsp.submap = "reset";
      "Return".dsp.submap = "reset";
    };

    submaps.hyprexpo.binds = {
      "H".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("left") end'';
      "J".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("down") end'';
      "K".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("up") end'';
      "L".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("right") end'';

      "Left".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("left") end'';
      "Down".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("down") end'';
      "Up".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("up") end'';
      "Right".dsp.__raw = ''function() hl.plugin.hyprexpo.kb_focus("right") end'';

      # Confirm the selected workspace and leave the submap
      "Return".dsp.__raw = confirmExpo;
      "Escape".dsp.__raw = confirmExpo;
      "Mod+Tab".dsp.__raw = confirmExpo;
    };

    general = {
      border_size = 2;
    };

    decoration = {
      rounding = 4;
      active_opacity = 0.75;
      inactive_opacity = 0.65;
      fullscreen_opacity = 1.0;

      shadow = {
        enabled = true;
        range = 15;
        render_power = 3;
        color_inactive = "rgba(1a1a1aaa)";
      };

      blur = {
        enabled = true;
        brightness = 0.4;
        size = 2;
        passes = 3;
        new_optimizations = true;
        ignore_opacity = true;
        xray = false;
        popups = true;
      };
    };

    input.follow_mouse = 2;

    plugins.hyprexpo = {
      # Layout and Behavior
      columns = 3;
      # rows = 0;
      gaps_in = 5;
      gaps_out = 10;
      bg_col = "rgb(${colors.base00})"; # Background color
      workspace_method = "center current";
      # overview_mode = "auto";
      skip_empty = 0;
      max_workspace = 0;
      cancel_key = "escape";
      show_cursor = 1;
      show_pinned_windows = 0;

      # Trackpad Gestures
      gesture_fingers = 3;
      gesture_direction = "vertical";
      gesture_distance = 200;

      # Tile Appearance
      tile_rounding = 8;
      tile_rounding_power = 2.0;
      tile_rounding_focus = -1;
      tile_rounding_current = -1;
      tile_rounding_hover = -1;
      border_width = 2;
      border_color = "";
      border_color_current = "rgb(${colors.base0D})"; # Primary accent (Blue)
      border_color_focus = "rgb(${colors.base0A})"; # Focus accent (Yellow)
      border_color_hover = "rgb(${colors.base0C})"; # Hover accent (Cyan)

      # Drag and Drop Styling
      drag_drop_proxy_color = "rgba(${colors.base0D}26)"; # Primary accent with ~15% opacity
      drag_drop_proxy_active_color = "rgba(${colors.base0D}4D)"; # Primary accent with ~30% opacity
      drag_drop_proxy_border_color = "rgb(${colors.base0D})";
      drag_drop_proxy_border_width = 2;
      drag_drop_proxy_rounding = 8;
      drag_drop_source_border_color = "rgb(${colors.base0A})";
      drag_drop_source_border_width = 2;

      # Workspace Labels
      label_enable = 1;
      label_text_mode = "token";
      label_position = "center";
      label_show = "always";
      label_color_default = "rgb(${colors.base05})"; # Foreground text
      label_color_hover = "rgb(${colors.base06})"; # Bright foreground text
      label_color_focus = "rgb(${colors.base0A})"; # Focused text
      label_color_current = "rgb(${colors.base0D})"; # Active workspace text
      label_font_size = 16;
      label_font_family = config.stylix.fonts.sansSerif.name; # Uses Stylix sans-serif font
      label_bg_enable = 1;
      label_bg_color = "rgba(${colors.base00}88)"; # Background with ~53% opacity
      label_bg_shape = "circle";

      # Selection Overlay
      selection_label_enable = 0;
      selection_label_token_map = "a,s,d,f,g,q,w,e,r,t";
      selection_label_position = "top-right";
      selection_label_color = "rgb(${colors.base0A})";

      # Keyboard Navigation
      keynav_enable = 1;
      number_key_mode = "workspace";
      keynav_wrap_h = 1;
      keynav_wrap_v = 1;
      keynav_reading_order = 0;
    };

    rules.win = [
      {
        match.class = "^(Vivaldi-stable|vivaldi-stable|zen|firefox)$";
        opacity = "1.0 1.0";
      }
    ];
  };
}
