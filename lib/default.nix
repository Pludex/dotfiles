{
  pkgs,
  args,
  ...
}:
let
  make = import ./make args;
in
{
  libx = {
    inherit make;
    mkDesktopWithIcon = make.desktopWithIcon;
    makeDesktopItem = make.desktopWithIcon;
  };
}
