{ lib, ... }:
let
  program = name: { modules.home.programs = [ name ]; };
  nixos-service = name: { modules.nixos.services = [ name ]; };
in
{
  modules = {
    home.programs = {
      waybar = ./waybar;
      swaync = ./swaync.nix;
      clipse = ./clipse.nix;
      hyprlock = ./hyprlock.nix;
      walker = ./walker.nix;
      wlogout = ./wlogout.nix;

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

    nixos.services = {
      tuigreet = ./tuigreet.nix;
    };
  };

  tools.desktop = {
    notification.swaync = program "swaync";
    launcher = lib.genAttrs [ "walker" "fuzzel" ] program;
    clipboard.clipse = program "clipse";
    logout.wlogout = program "wlogout";
    lock-screen.hyprlock = program "hyprlock";
    status-bar.waybar = program "waybar";
    display-manager.tuigreet = nixos-service "tuigreet";
  };
}
