{
  programs.bat = {
    enable = true;

    config = {
      # theme = "TwoDark";
      style = "numbers,changes,header";
      pager = "less -FR";
      italic-text = "always";
    };
  };
  stylix.targets.bat.enable = true;
}
