{ pkgs, ... }:
pkgs.linkFarm "assets" [
  {
    name = "icons";
    path = ./icons;
  }
  {
    name = "wallpapers/static";
    path = ./wallpapers/static;
  }
  {
    name = "wallpapers/live";
    path = ./wallpapers/live;
  }
  {
    name = "imgs";
    path = ./imgs;
  }
]
