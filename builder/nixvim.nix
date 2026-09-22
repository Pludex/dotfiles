{
  lib,
  config,
  inputs,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;

  mkConfig =
    base: profile: c:
    inputs.nixvim.lib.evalNixvim {
      extraSpecialArgs = {
        inherit base;
        inherit (base) inputs;
      };
      modules =
        cfg.nixvimModules
        ++ c.extraModules
        ++ [
          "${cfg.paths.modules}/nixvim"
          (import cfg.paths.profiles { inherit profile; }).nixvim
          # Overlays are baked into base.pkgs
          { nixpkgs.pkgs = base.pkgs; }
        ];
    };

  # Wraps the built nixvim in neovide, so `<profile>ide` starts a GUI with the
  # same config while `<profile>` is the plain terminal nvim.
  mkPackage =
    {
      profile,
      pkgs,
      nixvimPkg,
    }:
    pkgs.stdenv.mkDerivation {
      name = profile;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.neovide}/bin/neovide $out/bin/${profile}ide \
          --prefix PATH : "${nixvimPkg}/bin"
        ln -s ${nixvimPkg}/bin/nvim $out/bin/${profile}
      '';
      meta.mainProgram = profile;
    };

  # Every pkgs built through this flake's overlay chain (mkPkgs/mksPkgs)
  # already carries `pkgs.myPkgs.<profile>`, baked in by the overlay
  # below - so this is now a thin convenience wrapper, not the primary
  # way to get a profile's package.
  mkNvimPkg =
    { profile, pkgs }:
    pkgs.myPkgs.${profile} or (throw "base.nixvim: no profile '${profile}' in myPkgs");

  # `final` is the overlay fixed-point, so it's safe to use as `pkgs`
  # here even though this overlay is itself part of building that same
  # pkgs set - same pattern as the `paths.libx` overlay in base.nix.
  # This is what auto-injects every configured profile as
  # `myPkgs.<profile>` at the top level of every pkgs built via this
  # flake's overlay chain.
  mkMyPkgsOverlay =
    final: prev:
    let
      base = cfg.base.builder.mkCoreBase { pkgs = final; };
      nixvimConfigs = lib.mapAttrs (profile: c: mkConfig base profile c) cfg.nixvim;
    in
    {
      myPkgs =
        (prev.myPkgs or { })
        // lib.mapAttrs (
          profile: nvimCfg:
          mkPackage {
            inherit profile;
            pkgs = final;
            nixvimPkg = nvimCfg.config.build.package;
          }
        ) nixvimConfigs;
    };

  configurationType = lib.mkOptionType {
    name = "configuration";
    description = "configuration";
    descriptionClass = "noun";
    merge = lib.options.mergeOneOption;
    check = x: x._type or null == "configuration";
  };
in
{
  imports = [
    # Keeps the flake output shape nixvimConfigurations.<system>.<profile>
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "nixvimConfigurations";
      option = lib.mkOption {
        type = lib.types.lazyAttrsOf configurationType;
        default = { };
        description = ''
          An attribute set of Nixvim configurations.
        '';
      };
      file = ./nixvim.nix;
    })
  ];

  options = {
    # Modules added to every nixvim configuration
    nixvimModules = mkOption {
      type = types.listOf types.raw;
      default = [ ];
    };

    # Attr name is the profile
    nixvim = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.extraModules = mkOption {
            type = types.listOf types.raw;
            default = [ ];
          };
        }
      );
      default = { };
    };
  };

  config = {
    builder.mkNvimPkg = mkNvimPkg;
    builder.mkNixvimConfig = mkConfig;

    # Registers the overlay that bakes myPkgs.<profile> into every
    # pkgs built through this flake's overlay chain.
    overlays = [ mkMyPkgsOverlay ];

    perSystem =
      { base, ... }:
      {
        # Kept for introspection (flake output shape
        # nixvimConfigurations.<system>.<profile>) - note this
        # re-evaluates nixvim configs separately from the overlay
        # above, so it's a second evaluation, not a reuse of
        # base.pkgs.myPkgs.
        nixvimConfigurations = lib.mapAttrs (profile: c: mkConfig base profile c) cfg.nixvim;
      };
  };

}
