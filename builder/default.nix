{ inputs }:
{
  mkDotfiles =
    { ... }:
    let
      result = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          ./base.nix
          ./nixos.nix
          ./home.nix
          ./nixvim.nix
          ./package.nix
          ./profiles.nix

          ../outputs.nix

          ({ lib, ... }: {
            options.builder = lib.mkOption {
              type = lib.types.attrs;
            };
          })
        ];
      };
    in
    result // { __functor = _self: args: result.mkPkgsFor args; };
}
