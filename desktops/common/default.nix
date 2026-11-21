{ lib, ... }:
let
  program = name: { modules.home.programs = [ name ]; };
in
{
  modules.home.programs = {
    swaync = ./swaync;
    waybar = ./waybar;
    clipse = ./clipse.nix;
    hyprlock = ./hyprlock.nix;
    walker = ./walker.nix;

    wlogout = {
      programs.wlogout = {
        enable = true;
      };
    };

    fuzzel =
      { pkgs, ... }:
      {
        programs.fuzzel = {
          enable = true;
          package = pkgs.fuzzel;
        };
        stylix.targets.fuzzel.enable = true;
      };
  };

  tools.desktop = {
    notification.swaync = program "swaync";
    launcher = lib.genAttrs [ "walker" "fuzzel" ] program;
    clipboard.clipse = program "clipse";
    session-management.wlogout = program "wlogout";
    lock-screen.hyprlock = program "hyprlock";
  };
}
