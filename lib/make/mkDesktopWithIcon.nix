{ pkgs, ... }:
{
  desktopWithIcon =
    {
      iconPkg ? pkgs.myPkgs.icons,
      icon,
      ...
    }@args:
    let
      pathIcon = iconPkg.iconPaths.${icon} or (throw "mkDesktopWithIcon: no icon named '${icon}'");
    in
    pkgs.makeDesktopItem (removeAttrs args [ "iconPkg" ] // { icon = pathIcon; });
}
