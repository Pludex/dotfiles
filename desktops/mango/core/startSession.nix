{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs.mango.settings.startSessionWithApps = [
    {
      tags = [ 1 ];
      cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Profile 1" &'';
    }
    {
      tags = [ 1 ];
      cmd = "${lib.getExe pkgs.spotify} &";
    }
    {
      tags = [ 2 ];
      cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Default" &'';
    }
    {
      tags = [ 4 ];
      cmd = "${lib.getExe config.programs.ghostty.package} &";
    }
  ];
}
