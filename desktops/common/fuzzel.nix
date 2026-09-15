{ pkgs, ... }:
{
  programs.fuzzel = {
    enable = true;
    package = pkgs.fuzzel;
  };

  stylix.targets.fuzzel.enable = true;
}
