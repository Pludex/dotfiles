{ pkgs, ... }:
pkgs.runCommand "assets" { } ''
  mkdir -p $out/icons
  mkdir -p $out/wallpapers/static
  mkdir -p $out/wallpapers/live

  cp -r ${./icons}/* $out/icons/
  cp -r ${./wallpapers}/static/* $out/wallpapers/static
  cp -r ${./wallpapers}/live/* $out/wallpapers/live
''
