# { inputs, ... }:
{
  imports = [
    # inputs.plasma-manager.homeModules.plasma-manager
  ];
  programs.plasma = {
    enable = true;
  };

  stylix.targets.kde.enable = false;
}
