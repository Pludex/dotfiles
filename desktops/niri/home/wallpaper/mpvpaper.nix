{
  programs.mpvpaper = {
    enable = true;
  };
  programs.niri.settings.spawn-at-startup = [
    {
      argv = [
        "mpvpaper"
        "-o"
        "no-audio --loop-inf"
        "ALL"
        "/workspaces/nix-config/assets/kawaii-cat-girl.png"
      ];
    }
  ];
}
