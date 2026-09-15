{ base, ... }:
{
  programs.niri.settings.binds = {
    "Mod+A".action.spawn = "fuzzel";
  };

  imports = [
    "${base.commonDesktop}/fuzzel.nix"
  ];
}
