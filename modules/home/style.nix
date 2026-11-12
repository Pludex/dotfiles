{
  inputs,
  pkgs,
  config,
  base,
  lib,
  ...
}:
{
  imports = [ inputs.stylix.homeModules.default ];

  config = lib.mkMerge [
    {
      stylix = {
        enable = true;
        autoEnable = false;

        inherit (base)
          base16Scheme
          polarity
          cursor
          opacity
          fonts
          ;

        icons = {
          enable = true;
          inherit (base.icons) package dark light;
        };
      };

      fonts.fontconfig.enable = true;

      home.packages = [
        config.stylix.fonts.serif.package
        config.stylix.fonts.sansSerif.package
        config.stylix.fonts.monospace.package
        config.stylix.fonts.emoji.package

        pkgs.inter
        pkgs.dejavu_fonts
      ];
    }

    (lib.mkIf (!config.isContainer) {
      gtk = {
        enable = true;
      };
      home.file.".gtkrc-2.0".enable = false;
      stylix.targets.gtk.enable = true;

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
        config = {
          common = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
          };
          hyprland = {
            default = [
              "hyprland"
              "gtk"
            ];
          };
        };
      };

      home.sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };
    })
  ];
}
