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
  };
}
