{ inputs }:
{
  # Accepts nothing yet; the open argument set keeps future options non-breaking
  mkDotfiles =
    { ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./base.nix
        ./nixos.nix
        ./home.nix
        ./nixvim.nix
        ../outputs.nix

        (
          {
            config,
            lib,
            ...
          }:
          {
            # config.flake.__functor =
            #   _: args:
            #   config.base.mkPkgs {
            #     system = args.localSystem or "x86_64-linux";
            #     extraNixpkgsArgs = args;
            #   };

            options.builder = lib.mkOption { type = lib.types.attrs; };
          }
        )
      ];
    };
}
