{
  base,
  ...
}:
let
  make = import ./make base;
in
{
  libx = {
    inherit make;
    mkDesktopWithIcon = make.desktopWithIcon;
    makeDesktopItem = make.desktopWithIcon;

    tryOr =
      expr: fallback:
      let
        res = builtins.tryEval expr;
      in
      if res.success then res.value else fallback;
  };
}
