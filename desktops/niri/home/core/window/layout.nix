{ config, ... }:
{
  programs.niri.settings.layout = {
    gaps = 7;
    background-color = "transparent";
    focus-ring.enable = false;
    border = {
      enable = true;
      width = 2;
    };

    insert-hint = {
      enable = true;
      display.gradient = {
        from = "#${config.lib.stylix.colors.base0D}";
        to = "#${config.lib.stylix.colors.base0E}";
        angle = 45;
        relative-to = "window";
      };
    };

    shadow = {
      enable = true;
      softness = 40;
      spread = 10;
      offset = {
        x = 0;
        y = 8;
      };
      color = "#${config.lib.stylix.colors.base00}99";
      inactive-color = "#00000055";
      draw-behind-window = true;
    };

    preset-column-widths = [
      { proportion = builtins.div 1.0 3.0; } # 1/3
      { proportion = builtins.div 1.0 2.0; } # 1/2
      { proportion = builtins.div 2.0 3.0; } # 2/3
      { proportion = 1.0; }
    ];

    default-column-width = {
      proportion = 0.7;
    };

    always-center-single-column = true;
    default-column-display = "tabbed";

    tab-indicator = {
      enable = true;
      position = "left";
      width = 4;
      gap = 8;
      corner-radius = 10;
      gaps-between-tabs = 2;

      hide-when-single-tab = true;

      length.total-proportion = 0.8;
    };
  };
}
