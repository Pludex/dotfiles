{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "audio-manager";

  runtimeInputs = with pkgs; [
    python3
    pipewire
    wireplumber
    playerctl
  ];

  text = ''
    python3 -u ${./daemon.py} "$@"
  '';
}
