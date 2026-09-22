{ pkgs, ... }:
{
  xdg.portal = {
    enable = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];

    config.common.default = "*";
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
    "/share/gsettings-schemas"
    "/share/icons"
    "/share/dbus-1"
  ];
}
