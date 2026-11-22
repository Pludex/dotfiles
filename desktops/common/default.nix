{ lib, ... }:
let
  # backend whose modules live in one catalog of one framework
  mk = framework: catalog: name: {
    modules.${framework}.${catalog} = [ name ];
  };

  program = mk "home" "programs";
  service = mk "home" "services";
  nixos-service = mk "nixos" "services";

  # { a = program "a"; b = program "b"; }
  backends = kind: names: lib.genAttrs names kind;
in
{
  modules = {
    home = {
      programs = {
        waybar = ./waybar;
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

      services = {
        clipse = ./clipse.nix;
        swaync = ./swaync.nix;
      };
    };

    nixos.services.tuigreet = ./tuigreet.nix;
  };

  tools.desktop = {
    notification = backends service [ "swaync" ];
    launcher = backends program [
      "walker"
      "fuzzel"
    ];
    clipboard = backends service [ "clipse" ];
    logout = backends program [ "wlogout" ];
    lock-screen = backends program [ "hyprlock" ];
    status-bar = backends program [ "waybar" ];
    display-manager = backends nixos-service [ "tuigreet" ];
  };
}
