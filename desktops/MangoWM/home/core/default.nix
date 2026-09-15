{ inputs, ... }:
{
  wayland.windowManager.mango = {
    enable = true;
  };

  imports = [
    inputs.MangoWM.hmModules.mango
    ./binds.nix
    ./window.nix
  ];

}
