{
  lib,
  pkgs,
  ...
}:
let
  wallpapers = pkgs.myPkgs.wallpapers;

  restoreBin = "${wallpapers.restoreWallpaper}/bin/restore-wallpaper";
  pickBin = "${wallpapers.wallpaperPicker}/bin/pick-wallpaper";
  setStaticBin = "${wallpapers.setStatic}/bin/set-static-wallpaper";
  setLiveBin = "${wallpapers.setLive}/bin/set-live-wallpaper";
  toggleBin = "${wallpapers.toggleWallpaper}/bin/toggle-wallpaper";
in
{
  options.programs.mango.settings.wallpaperStart = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Shell commands run at WM startup to set the wallpaper.";
  };

  config.programs.mango.settings = {
    wallpaperStart = ''
      ${restoreBin} &
    '';

    bind = [
      "SUPER,P,spawn,${pickBin}"
      "SUPER+SHIFT,P,spawn,${setStaticBin}"
      "SUPER+ALT,P,spawn,${setLiveBin}"
      "SUPER+CTRL,P,spawn,${toggleBin}"
    ];
  };
}
