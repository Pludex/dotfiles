{ pkgs, myPkgs, ... }:
pkgs.writeShellApplication {
  name = "brightness-control";

  runtimeInputs = with pkgs; [
    brightnessctl
    libnotify
    gawk
    gnused
    bash
  ];

  text = ''
    export iDIR="${myPkgs.assets}/icons"
    bash ${./brightness-control.sh} "$@"
  '';
}
