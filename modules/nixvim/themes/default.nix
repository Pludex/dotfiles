let
  theme = name: { modules.nixvim.themes = [ name ]; };
in
{
  modules.nixvim.theme = {
    catppuccin = ./catppuccin.nix;
    nightfox = ./nightfox.nix;
    tokyonight = ./tokyonight.nix;
  };

  tools.nixvim.theme = {
    catppuccin = theme "catppuccin";
    nightfox = theme "nixghtfox";
    tokyonight = theme "tokyonight";
  };
}
