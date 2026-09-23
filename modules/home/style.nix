{
  inputs,
  pkgs,
  config,
  ...
}:
{
  stylix = {
    enable = true;

    base16Scheme = "${inputs.schemes}/base16/nightfox-carbonfox.yaml";

    polarity = "dark";

    cursor = {
      package = pkgs.bibata-cursors;
      # name = "Bibata-Modern-Classic";
      name = "Bibata-Original-Classic";
      size = 22;
    };

    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };

    opacity = {
      terminal = 0.5;
      applications = 0.9;
      desktop = 0.9;
      popups = 0.9;
    };

    fonts = {
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };

      sansSerif = {
        package = pkgs.nerd-fonts.ubuntu-sans;
        name = "UbuntuSans NF";
      };

      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };

      sizes = {
        terminal = 9;
      };
    };

    autoEnable = false;
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

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  imports = [ inputs.stylix.homeModules.default ];
}
