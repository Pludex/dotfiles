{ pkgs, ... }:
{
  extraPlugins = [
    pkgs.myPkgs.treesitter-kanata-vimPlugin
  ];

  filetype.extension.kbd = "kanata";
  plugins.treesitter.languageRegister.kanata = "kbd";
}
