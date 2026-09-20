{
  extraModules,
  extraOverlays,
  nixpkgsConfig,
  inputs,
}:
let
  mkBuilderWithSelf =
    { self }:
    let
      # mkPkgs is only forced when includePkgs = true, so this recursive let is safe.
      inherit (import ./args.nix { inherit inputs mkPkgs; }) mkArgs;

      args = mkArgs {
        extraArgs' = {
          builder = self;
        }
        // self;
        includePkgs' = false;
      };

      inherit (args) base;

      mkNixosModules =
        {
          host,
          profile,
          desktop,
          extraNixosModules,
        }:
        extraModules.nixos
        ++ extraNixosModules
        ++ [
          "${base.modules}/nixos"
          (import base.hosts { inherit host; })
          (import base.profiles { inherit profile; }).nixos
          (import base.desktops { inherit desktop; }).nixos
        ];

      mkHomeModules =
        {
          profile,
          desktop,
          extraHomeModules,
        }:
        extraModules.home
        ++ extraHomeModules
        ++ [
          "${base.modules}/home"
          (import base.profiles { inherit profile; }).home
          (import base.desktops { inherit desktop; }).home
        ];

      mkNixvimModules =
        { profile, extraNixvimModules }:
        extraModules.nixvim
        ++ extraNixvimModules
        ++ [
          "${base.modules}/nixvim"
          (import base.profiles { inherit profile; }).nixvim
        ];

      inherit
        (import ./pkgs.nix {
          inherit
            extraOverlays
            nixpkgsConfig
            inputs
            args
            ;
        })
        mkPkgs
        ;

      home = import ./home.nix { inherit mkPkgs mkHomeModules args; };
      nixos = import ./nixos.nix {
        inherit mkPkgs mkNixosModules args;
        mkHome = home.mkNonStandalone;
      };
      nixvim = import ./nixvim.nix { inherit mkPkgs mkNixvimModules args; };
    in
    {
      inherit mkPkgs;
      mkNixos = nixos.mk;
      mkHome = home.mk;
      mkNixvim = nixvim.mk;
      mkNvimPkg = nixvim.mkPackage;
    };

  output = mkBuilderWithSelf { self = output; };
in
output
