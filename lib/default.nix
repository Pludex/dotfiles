{
  libx = {
    tryOr =
      expr: fallback:
      let
        res = builtins.tryEval expr;
      in
      if res.success then res.value else fallback;
  };

  perSystem = { pkgs, config, ... }: {
    libx = {
      make.desktopWithIcon =
        {
          iconPkg ? pkgs.myPkgs.icons,
          icon,
          ...
        }@args:
        let
          pathIcon = iconPkg.iconPaths.${icon} or (throw "mkDesktopWithIcon: no icon named '${icon}'");
        in
        pkgs.makeDesktopItem (removeAttrs args [ "iconPkg" ] // { icon = pathIcon; });

      mkDesktopWithIcon = config.libx.make.desktopWithIcon;
      makeDesktopItem = config.libx.make.desktopWithIcon;
    };
  };
}
