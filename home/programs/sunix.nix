{
  pkgs,
  base,
  inputs,
  config,
  osConfig,
  ...
}:
{
  imports = with inputs; [
    sunix.homeModules.default
  ];

  programs.sunix = {
    enable = true;

    settings = {
      dixBinary = "${pkgs.dix}/bin/dix";
      flakeDir = base.abs.dotfiles;
      homeFlake = config.name;
      nixosFlake = osConfig.name;
      styleCss = null;
      showDemo = false;
    };
  };
}
