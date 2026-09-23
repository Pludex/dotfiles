{ inputs, pkgs, ... }:
{
  imports = [
    inputs.nsticky.homeModules.default
  ];

  programs.nsticky = {
    enable = true;
    menu = "${pkgs.fuzzel}/bin/fuzzel -d";
  };

  programs.niri.settings = {
    spawn-at-startup = [
      { argv = [ "nsticky" ]; }
    ];

    workspaces = {
      "stage" = { };
    };

    binds = {
      "Mod+Ctrl+Space".action.spawn = [
        "nsticky"
        "sticky"
        "toggle-active"
      ];
      "Mod+Shift+Space".action.spawn = [
        "nsticky"
        "stage"
        "toggle-active"
      ];
      "Mod+Shift+R".action.spawn = [
        "nsticky"
        "stage"
        "restore"
      ];
    };
  };
}
