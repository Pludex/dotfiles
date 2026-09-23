{ base, ... }:
{
  nix.registry = {
    nixpkgs.to = {
      type = "path";
      path = base.abs.dotfiles;
    };

    dotfiles.to = {
      type = "path";
      path = base.abs.dotfiles;
    };
  };
}
