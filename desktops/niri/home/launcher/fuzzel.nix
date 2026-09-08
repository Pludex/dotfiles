{
  programs.fuzzel = {
    enable = true;
  };

  programs.niri.settings.binds = {
    "Mod+A".action.spawn = "fuzzel";
  };

  stylix.targets.fuzzel.enable = true;
}
