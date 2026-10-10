{
  lib,
  pkgs,
  config,
  ...
}:
let
  ignoreClasses = lib.concatStringsSep "," [
    "vivaldi-stable"
    "spotify"
    "com.mitchellh.ghostty"
  ];
  hyprsession = lib.getExe pkgs.hyprlandPlugins.hyprsession;
in
{
  programs.hyprland.settings.startWith = {
    apps = [
      {
        cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Profile 1"'';
        opts.workspace = "8";
      }
      {
        cmd = lib.getExe pkgs.spotify;
        opts.workspace = "8";
      }
      {
        cmd = ''${lib.getExe pkgs.vivaldi} --profile-directory="Default"'';
        opts.workspace = "1";
      }
      {
        cmd = lib.getExe config.programs.ghostty.package;
        opts.workspace = "2";
      }
    ];

    actions = [
      {
        dsp.exec_cmd = "env HYPRSESSION_IGNORE_CLASSES=${ignoreClasses} ${hyprsession}";
      }
    ];
  };

  home.packages = [
    pkgs.hyprlandPlugins.hyprdrover
    pkgs.hyprlandPlugins.hyprsession
  ];

  systemd.user.services.hyprsession-save = {
    Unit = {
      Description = "Save Hyprland session with hyprsession";
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
    };
    Service = {
      Type = "oneshot";
      Environment = [ "HYPRSESSION_IGNORE_CLASSES=${ignoreClasses}" ];
      ExecStart = "${hyprsession} save autosave";
    };
  };

  systemd.user.timers.hyprsession-save = {
    Unit.Description = "Periodic hyprsession save";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
