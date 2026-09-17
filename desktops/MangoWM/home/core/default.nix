{ inputs, ... }:
{
  wayland.windowManager.mango = {
    enable = true;
  };

  imports = [
    inputs.MangoWM.hmModules.mango
    ./autostart.nix
    ./binds.nix
    ./input.nix
    ./layout.nix
    ./startSession.nix
    ./window.nix
  ];
}
