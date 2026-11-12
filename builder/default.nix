{ inputs }:
{
  mkDotfiles =
    _:
    let
      result = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          ./base.nix
          ./nixos.nix
          ./home.nix
          ./host.nix
          ./nixvim.nix
          ./package.nix
          ./profiles.nix

          ../outputs.nix
        ];
      };
    in
    result // { __functor = _self: args: result.mkPkgsFor args; };
}
