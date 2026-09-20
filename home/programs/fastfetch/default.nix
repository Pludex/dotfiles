{ pkgs, ... }:
{
  programs.fastfetch = {
    enable = true;
  };
  xdg.configFile."fastfetch/config.jsonc".source = ./config.jsonc;
  xdg.configFile."fastfetch/logo/nixos.webp".source = "${pkgs.myPkgs.assets}/imgs/nixos.webp";
}
