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
    ++ [ (final: prev: args) ]
    ++ (import "${base.overlays}" args)
    ++ (import "${base.pkgs}" args);
  config = nixpkgsConfig;
in
{
  mkPkgs =
    {
      system,
      extraNixpkgsArgs ? { },
    }:
    import inputs.nixpkgs (
      {
        inherit overlays config;
        localSystem = system;
      }
      // extraNixpkgsArgs
    );
}
