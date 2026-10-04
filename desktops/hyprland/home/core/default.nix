{
  programs.hyprland.settings = {
    mainMod = "SUPER";
    binds = {
      # "Mod+E".dsp.exit = true;
      "Mod+F".dsp.exec_cmd = "hyprctl reload";
    };
  };

  imports = [
    ./animation.nix
    ./input.nix
    ./layout.nix
    ./rules.nix
    ./window.nix
  ];

  programs.hyprland.monitors = {
    "" = {
      scale = 1.0;
    };
  };
}
