{
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    myPkgs.editor
    myPkgs.leetcode
  ];

  programs.neovide = {
    enable = true;
    settings = {
      font.size = config.stylix.fonts.sizes.terminal;
      font.normal = config.stylix.fonts.monospace.name;
      wayland-app-id = "neovim";
    };
  };
}
