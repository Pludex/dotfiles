{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vivaldi
    vivaldi-ffmpeg-codecs

    myPkgs.vivaldi-sync
  ];

  home.sessionVariables.BROWSER = "vivaldi";
}
