{ pkgs, myPkgs, ... }:

pkgs.writeShellApplication {
  name = "volume-control";

  runtimeInputs = with pkgs; [
    wireplumber
    libnotify
    bc
    bash
  ];

  text = ''
    export iDIR="${myPkgs.assets}/icons"
    bash ${./volume-control.sh} "$@"
  '';
}
