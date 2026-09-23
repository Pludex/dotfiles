{ pkgs, ... }:
{
  extraPackages = [ pkgs.imagemagick ];
  plugins.snacks.settings.image = {
    enabled = true;
  };
}
