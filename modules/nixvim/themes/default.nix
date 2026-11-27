let
  theme = name: { modules.nixvim.themes = [ name ]; };
in
{
  modules.nixvim.themes = {
    catppuccin = ./catppuccin.nix;
    nightfox = ./nightfox.nix;
    tokyonight = ./tokyonight.nix;
  };

  tools.nixvim.theme = {
    catppuccin = theme "catppuccin";
    nightfox = theme "nightfox";
    tokyonight = theme "tokyonight";
  };

  defaults.tools.nixvim.theme = "nightfox";
}
