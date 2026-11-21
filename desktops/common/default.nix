{ lib, ... }:
let
  program = name: { modules.home.programs = [ name ]; };
  service = name: { modules.home.service = [ name ]; };
in
{
  modules = {
    home.programs = {
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

    nixos.modules = {
      tuigreet = ./tuigreet.nix;
    };
  };

  tools.desktop = {
    notification.swaync = program "swaync";
    launcher = lib.genAttrs [ "walker" "fuzzel" ] program;
    clipboard.clipse = program "clipse";
    session-management.wlogout = program "wlogout";
    lock-screen.hyprlock = program "hyprlock";
    status-bar.waybar = program "waybar";
    display-manager = service "tuigreet";
  };
}
