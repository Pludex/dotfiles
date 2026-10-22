{
  base,
  lib,
  osConfig ? null,
  ...
}:
{
  config = {
    home.username = base.username;
    home.homeDirectory = base.abs.home;
    home.stateVersion = "26.05";

    programs.man.generateCaches = false;

    home.sessionVariables = base.tools.envvars;
    isContainer = if (osConfig == null) then lib.mkDefault false else osConfig.isContainer;
  };

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  imports = [
    ./input-method
    ./programs
    ./services
    ./gtk.nix
    ./nix-config.nix
    ./sops.nix
    ./style.nix
    ./systemd.nix
    ./xdg.nix
  ];
}
