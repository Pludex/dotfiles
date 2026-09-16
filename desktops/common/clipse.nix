{ config, ... }:
let
  c = config.lib.stylix.colors;
in
{
  services.clipse = {
    enable = true;

    settings = {
      maxHistory = 500;

      keyBindings = {
        "save" = "s";
        "delete" = "d";
        "select" = "enter";

        "down" = "j";
        "up" = "k";
        "prevPage" = "h";
        "nextPage" = "l";
        "top" = "g";
        "bottom" = "G";

        # "delete" = "x";

        "filter" = "f";
        "quit" = "q,esc";
      };

      imageDisplay = {
        type = "kitty";
        scaleX = 9;
        scaleY = 9;
        heightCut = 2;
      };
    };

    theme = {
      "UseCustom" = true;

      "TitleFore" = "#${c.base05}";
      "TitleBack" = "#${c.base0E}";
      "TitleInfo" = "#${c.base0D}";

      "NormalTitle" = "#${c.base05}";
      "DimmedTitle" = "#${c.base03}";
      "NormalDesc" = "#${c.base04}";
      "DimmedDesc" = "#${c.base03}";

      "SelectedTitle" = "#${c.base08}";
      "SelectedDesc" = "#${c.base08}";
      "SelectedBorder" = "#${c.base0D}";
      "SelectedDescBorder" = "#${c.base0D}";

      "StatusMsg" = "#${c.base0B}";
      "PinIndicatorColor" = "#${c.base0A}";

      "FilteredMatch" = "#${c.base09}";
      "FilterPrompt" = "#${c.base0B}";
      "FilterInfo" = "#${c.base0C}";
      "FilterText" = "#${c.base05}";
      "FilterCursor" = "#${c.base0A}";

      "HelpKey" = "#${c.base04}";
      "HelpDesc" = "#${c.base03}";
      "PageActiveDot" = "#${c.base0D}";
      "PageInactiveDot" = "#${c.base03}";
      "DividerDot" = "#${c.base0D}";

      "PreviewedText" = "#${c.base05}";
      "PreviewBorder" = "#${c.base0D}";
    };
  };
}
