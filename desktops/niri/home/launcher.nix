{ base, ... }:
{
  programs.niri.settings.binds = {
    "Mod+A".action.spawn = "fuzzel";
  };

  imports = [
    "${base.paths.commonDesktop}/fuzzel.nix"
  ];
}
