{
  inputs,
  config,
  lib,
  base,
  ...
}:
let
  settings = {
    close_when_open = true;
    click_to_close = true;
    force_keyboard_focus = true;
    selection_wrap = true;
    show_initial_entries = true;
    placeholder = "Search apps, type = for calc, : for clipboard...";
    as_window = false;
    terminal = "${lib.getExe base.tools.term}";
    providers.default = [
      "desktopapplications"
      "calc"
      "runner"
    ];
    calc.prefix = "=";
    clipboard.prefix = ":";
    runner.prefix = "!";
    windows.prefix = "$";
  };

  inherit (lib)
    mkIf
    mkMerge
    mkDefault
    importTOML
    recursiveUpdate
    optionalAttrs
    ;

  cfg = config.stylix.targets.walker;
  themed = config.stylix.enable && cfg.enable;

  colors = config.lib.stylix.colors.withHashtag;
  inherit (config.stylix) fonts opacity;

  fontSize = fonts.sizes.popups;

  # Upstream defaults, overridden below in a single definition
  upstreamConfig = importTOML "${inputs.walker}/resources/config.toml";
in
{
  imports = [
    inputs.walker.homeManagerModules.walker
  ];

  options.stylix.targets.walker.enable = config.lib.stylix.mkEnableTarget "Walker" true;

  config = mkMerge [
    {
      # autoEnable = false in stylix, so enable this target explicitly
      stylix.targets.walker.enable = mkDefault true;

      programs.walker = {
        enable = true;
        runAsService = true;

        config = recursiveUpdate upstreamConfig (settings // optionalAttrs themed { theme = "stylix"; });
      };
    }

    (mkIf themed {
      programs.walker.themes.stylix.style = ''
        @define-color window_bg_color ${colors.base00};
        @define-color accent_bg_color ${colors.base0D};
        @define-color accent_fg_color ${colors.base00};
        @define-color theme_fg_color ${colors.base05};
        @define-color error_bg_color ${colors.base08};
        @define-color error_fg_color ${colors.base00};
        @define-color success_bg_color ${colors.base0B};
        @define-color warning_bg_color ${colors.base0A};

        * {
          font-family: "${fonts.sansSerif.name}";
          font-size: ${toString fontSize}pt;
          color: ${colors.base05};
        }

        .box-wrapper {
          background: alpha(${colors.base00}, ${toString opacity.popups});
          border: 2px solid ${colors.base0D};
          border-radius: 12px;
          padding: 12px;
        }

        .search-container {
          background: alpha(${colors.base01}, ${toString opacity.popups});
          border: 1px solid ${colors.base02};
          border-radius: 8px;
        }

        .input {
          background: transparent;
          font-size: ${toString (fontSize + 3)}pt;
          caret-color: ${colors.base0D};
          color: ${colors.base05};
        }

        .input placeholder {
          color: ${colors.base03};
        }

        .list {
          background: transparent;
        }

        child:selected .item-box,
        row:selected .item-box {
          background: alpha(${colors.base02}, ${toString opacity.popups});
          border-left: 3px solid ${colors.base0D};
          border-radius: 8px;
        }

        .item-text {
          font-size: ${toString fontSize}pt;
          color: ${colors.base05};
        }

        .item-subtext {
          font-size: ${toString (fontSize - 2)}pt;
          color: ${colors.base04};
        }

        .item-image {
          -gtk-icon-size: ${toString (fontSize * 3)}px;
        }

        /* Remove border, margin, and background from the main scrollbar container */
        scrollbar {
          background: transparent;
          border: none;
          margin: 0;
          padding: 0;
        }

        /* Remove border and background from the trough (scrollbar channel) */
        scrollbar trough {
          background: transparent;
          border: none;
        }

        /* Style the slider cleanly without any unwanted borders */
        scrollbar slider {
          min-width: 6px;   /* Width of the vertical slider */
          min-height: 6px;  /* Height of the horizontal slider */
          border: none;     /* Remove default GTK borders */
          margin: 2px;      /* Slight margin to avoid GTK size allocation errors */
          background: ${colors.base03};
          border-radius: 4px;
        }

        /* Optional hover state */
        scrollbar slider:hover {
          background: ${colors.base0D};
        }
      '';
    })
  ];
}
