{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs.hyprland.settings.startWith = {
    apps = [
      {
        cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Profile 1"'';
        opts = {
          workspace = "1";
        };
      }
      {
        cmd = "${lib.getExe pkgs.spotify}";
        opts = {
          workspace = "1";
        };
      }
      {
        cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Default"'';
        opts = {
          workspace = "2";
        };
      }
      {
        cmd = "${lib.getExe config.programs.ghostty.package}";
        opts = {
          workspace = "3";
        };
      }
    ];
  };
}
