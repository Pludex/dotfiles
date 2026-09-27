{
  programs.hyprland.settings = {
    binds = {
      "Mod+Q".dsp."window.close" = true;

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
    };
  };
}
