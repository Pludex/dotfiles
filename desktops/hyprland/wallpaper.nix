{ pkgs, ... }:
{
  programs.hyprland.settings = {
    misc = {
      disable_hyprland_logo = true;
      force_default_wallpaper = 0;
      disable_splash_rendering = true;
    };

    startWith.actions = [
      {
        dsp.exec_cmd = "${pkgs.myPkgs.wallpapers}/bin/restore-wallpaper";
      }
    ];

    binds = {
      "Mod+P".dsp.exec_cmd = "${pkgs.myPkgs.wallpapers.wallpaperPicker}/bin/pick-wallpaper";
    };
  };
}
