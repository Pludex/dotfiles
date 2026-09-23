{
  lib,
  pkgs,
  ...
}:
let
  wallpapers = pkgs.myPkgs.wallpapers;

  setStaticBin = "${wallpapers.setStatic}/bin/set-static-wallpaper";
  setLiveBin = "${wallpapers.setLive}/bin/set-live-wallpaper";
  toggleBin = "${wallpapers.toggleWallpaper}/bin/toggle-wallpaper";
in
{
  options.programs.mango.settings.wallpaperStart = lib.mkOption {
    type = lib.types.lines;
    default = "";
  };

  config.programs.mango.settings = {
    wallpaperStart = ''
      ${setStaticBin} &
    '';

    bind = [
      "SUPER,P,spawn,${setStaticBin}"
      "SUPER+SHIFT,P,spawn,${setLiveBin}"
      "SUPER+CTRL,P,spawn,${toggleBin}"
    ];
  };
}
