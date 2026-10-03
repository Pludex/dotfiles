{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config = {
      common = {
        default = [
          "hyprland"
          "kde"
        ];
      };
      hyprland = {
        default = [
          "hyprland"
          "kde"
        ];
      };
    };
  };

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
  stylix.targets.kde.enable = true;
}
