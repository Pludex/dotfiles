{ pkgs, ... }:
{
  home.packages = with pkgs; [
    awww
  ];

  programs.niri.settings.spawn-at-startup = [
    { command = [ "awww-daemon" ]; }
    {
      command = [
        "awww"
        "img"
        "${pkgs.myPkgs.assets}/kawaii-cat-girl.png"
      ];
    }
  ];

  programs.niri.settings.layer-rules = [
    {
      matches = [ { namespace = "^awww-daemon$"; } ];
      place-within-backdrop = true;
    }
  ];
}
