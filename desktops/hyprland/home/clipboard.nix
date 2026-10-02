{ pkgs, base, ... }:
{
  home.packages = [
    pkgs.wl-clipboard
  ];

  imports = [ "${base.paths.commonDesktop}/clipse.nix" ];

  programs.hyprland.settings = {
    binds."Mod+V".dsp.exec_cmd = "kitty --class clipse -e clipse";

    rules.win = [
      {
        match.class = "^clipse$";
        float = true;
        size = [
          600
          650
        ];
        center = true;
        suppress_event = "maximize fullscreen";
      }
    ];
  };
}
