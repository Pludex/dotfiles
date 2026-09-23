{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;

    scripts = with pkgs.mpvScripts; [
      uosc
      thumbfast
      mpris
    ];

    config = {
      slang = "vie,vi,eng,en";
      alang = "jpn,ja,eng,en";

      hwdec = "auto-safe";

      volume = 80;
      volume-max = 150;

      save-position-on-quit = true;

      osc = "no";
      osd-bar = "no";
      border = "no";
      cursor-autohide = 400;
    };
  };
}
