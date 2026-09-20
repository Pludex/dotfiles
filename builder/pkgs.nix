{
  extraOverlays,
  inputs,
  nixpkgsConfig,
  args,
}:
let
  inherit (args) base;

  overlays =
    extraOverlays
    ++ [
      (final: prev: args)
      (
        final: prev:
        (
          import base.libx {
            pkgs = final;
            args = args // {
              pkgs = final;
            };
          }
          // args
        )
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
