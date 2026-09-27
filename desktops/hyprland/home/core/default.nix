{
  programs.hyprland.settings = {
    mainMod = "SUPER";
    binds = {
      "Mod+E".dsp.exit = true;
      "Mod+R".dsp.exec_cmd = "hyprctl reload";
    };
  };

  imports = [
    ./window.nix
  ];

  programs.hyprland.monitors = {
    "" = {
      scale = 1.0;
    };
  };
}
