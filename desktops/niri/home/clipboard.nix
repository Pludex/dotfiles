{ pkgs, base, ... }:
{
  programs.niri.settings = {
    binds = {
      "Mod+V".action.spawn = [
        "kitty"
        "--class"
        "clipse"
        "-e"
        "clipse"
      ];
    };

    window-rules = [
      {
        matches = [
          {
            app-id = "clipse";
          }
        ];

        open-floating = true;

        default-column-width = {
          fixed = 600;
        };
        default-window-height = {
          fixed = 650;
        };

        draw-border-with-background = false;
      }
    ];
  };
  home.packages = [
    pkgs.wl-clipboard
  ];

  imports = [ "${base.paths.commonDesktop}/clipse.nix" ];
}
