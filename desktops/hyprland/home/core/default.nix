{
  programs.hyprland.settings = {
    mainMod = "ALT";
    binds = {
      "Mod+E".dsp = [ { exit = true; } ];
      "Mod+R".dsp = [ { exec_cmd = "hyprctl reload"; } ];
    };
  };
}
