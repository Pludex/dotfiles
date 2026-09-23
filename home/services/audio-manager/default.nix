{ pkgs, ... }:
{
  systemd.user.services.audio-manager = {
    Unit = {
      Description = "Smart Audio Ducking Service (PipeWire/WirePlumber)";
      After = [
        "pipewire.service"
        "wireplumber.service"
      ];
      Wants = [
        "pipewire.service"
        "wireplumber.service"
      ];
    };

    Service = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.myPkgs.audio-manager}/bin/audio-manager
      '';

      Restart = "on-failure";
      RestartSec = "5s";

      StandardOutput = "journal";
      StandardError = "journal";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
