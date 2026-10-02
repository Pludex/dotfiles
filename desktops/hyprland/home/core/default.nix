{
  programs.hyprland.settings = {
    mainMod = "SUPER";
    binds = {
      "Mod+E".dsp.exit = true;
      "Mod+R".dsp.exec_cmd = "hyprctl reload";
    };
  };

  imports = [
    ./animation.nix
    ./input.nix
    ./window.nix
    ./layout.nix
  ];

  programs.hyprland.monitors = {
    "" = {
      scale = 1.0;
    };
  };
}
