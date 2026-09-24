{ pkgs, ... }:
{
  extraPlugins = [
    pkgs.myPkgs.vimPlugins.treesitter-kanata
  ];

  filetype.extension.kbd = "kanata";
  plugins.treesitter.languageRegister.kanata = "kbd";
}
