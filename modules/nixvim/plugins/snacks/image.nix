{ pkgs, ... }:
{
  extraPackages = [ pkgs.imagemagick ];
  plugins.snacks = {
    enable = true;

    settings.image = {
      enabled = true;
    };
  };
}
