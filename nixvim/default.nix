{ inputs, ... }:
{
  nixpkgs.source = inputs.nixpkgs;

  imports = [
    ./core
    ./edit
    ./file
    ./git
    ./languages
    ./terminal
    ./ui
    ./utils
    ./workspace

    ./direnv.nix
    ./img.nix
    ./leetcode.nix
    ./neovide.nix
    ./obsidian.nix
    ./window.nix
  ];
}
