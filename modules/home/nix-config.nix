{
  lib,
  config,
  ...
}:
let
  inherit (config) isContainer;
in
{
  config = lib.mkMerge [
    (lib.mkIf (!isContainer) {
      nix.registry = {
        nixpkgs.to = {
          type = "git";
          url = "file:///workspaces/dotfiles";
        };

        dotfiles.to = {
          type = "git";
          url = "file:///workspaces/dotfiles";
        };
      };
    })

    (lib.mkIf isContainer {
      nix.registry.nixpkgs.to = {
        type = "git";
        url = "file:///workspaces/dotfiles-ref";
      };
    })
  ];
}
