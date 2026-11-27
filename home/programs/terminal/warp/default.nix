{ config, pkgs, ... }:
{
  programs.warp = {
    enable = true;
    package = pkgs.myPkgs.warp;

    settings = {
      appearance.text = {
        font_name = config.stylix.fonts.monospace.name;
        font_size = config.stylix.fonts.sizes.terminal;
      };
    };
  };

  imports = [
    ./module.nix
  ];
}
