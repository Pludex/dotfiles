{ inputs, ... }:
{
  wayland.windowManager.mango = {
    enable = true;
  };

  imports = [
    inputs.MangoWM.hmModules.mango
    ./autostart.nix
    ./binds.nix
    ./layout.nix
    ./window.nix
  ];
}
