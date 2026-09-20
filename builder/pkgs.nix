{
  extraOverlays,
  inputs,
  nixpkgsConfig,
  args,
}:
# Overlays must never see an args carrying pkgs, otherwise
# pkgs -> mkPkgs -> overlays -> args.pkgs -> pkgs recurses forever.
assert !(args ? pkgs) || throw "pkgs.nix: args must be built with includePkgs' = false";
let
  inherit (args) base;

  overlays =
    extraOverlays
    ++ [
      (
        final: prev:
        import base.libx {
          pkgs = final;
          # Only this args copy has pkgs; the original stays pkgs-free.
          args = args.mkArgs {
            includePkgs = true;
            extraArgs = {
              pkgs = final;
            };
          };
        }
        # Lets callPackage auto-fill `sources` in base.pkgs.
        // args
      )
    ]
    ++ (import "${base.overlays}" args)
    ++ (import "${base.pkgs}" args);
  config = nixpkgsConfig;
in
rec {
  mkPkgs =
    {
      system,
      extraNixpkgsArgs ? { },
      extraNixpkgsStableArgs ? { },
    }:
    import inputs.nixpkgs (
      {
        inherit config;
        localSystem = system;
        overlays = [
          (final: prev: {
            stable = mkPkgsStable {
              inherit system;
              extraNixpkgsArgs = extraNixpkgsStableArgs;
            };
          })
        ]
        ++ overlays;
      }
      // extraNixpkgsArgs
    );

  mkPkgsStable =
    {
      system,
      extraNixpkgsArgs ? { },
    }:
    import inputs.nixpkgs-stable (
      {
        inherit overlays config;
        localSystem = system;
      }
      // extraNixpkgsArgs
    );
}
