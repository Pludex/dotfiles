{
  lib,
  config,
  inputs,
  flake-parts-lib,
  getSystem,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;

  defaultSystem = builtins.head cfg.systems;

  # Never walked into: non-attrsets, derivations, option types (_type),
  # evalModules/nixosSystem results
  defaultIsLeaf =
    v:
    !(builtins.isAttrs v)
    || lib.isDerivation v
    || v ? outPath
    || v ? _type
    || (v ? config && v ? options);

  mkTree =
    isLeaf:
    let
      t = lib.mkOptionType {
        name = "tree";
        description = "leaf value or nested attribute set";
        descriptionClass = "noun";
        check = _: true;
        merge =
          loc: defs:
          if lib.any (d: isLeaf d.value) defs then
            lib.mergeOneOption loc defs
          else
            (types.lazyAttrsOf t).merge loc defs;
      };
    in
    t;

  # Local copy used to declare `libx` itself (bootstrap); everything else
  # uses cfg.libx.types.tree
  tree = mkTree defaultIsLeaf;

  disjoint =
    what: a: b:
    let
      clash = builtins.attrNames (builtins.intersectAttrs a b);
    in
    lib.assertMsg (
      clash == [ ]
    ) "base: ${what} redefines built-in key(s): ${lib.concatStringsSep ", " clash}";

  fixed = {
    inherit inputs;
    inherit (cfg) paths;
    sources = inputs;
  };

  # `core` must never depend on `pkgs`: pkgs -> overlays -> core -> pkgs would recurse
  core =
    assert disjoint "builder" cfg.builder (fixed // { base = null; });
    assert disjoint "extraBase" cfg.extraBase (fixed // cfg.builder // { base = null; });
    let
      self =
        fixed
        // cfg.builder
        // cfg.extraBase
        // {
          base = self;
          builder = cfg.builder;
        };
    in
    self;

  # Not a full `base`: safe to call from overlays (pass `final`)
  mkCoreBase = { pkgs }: core // { inherit pkgs; };

  overlays =
    system:
    cfg.overlaysOfInputs
    ++ [
      (final: prev: prev // (getSystem system).packagesOfInputs)
      (final: prev: { base = core; })
      (final: prev: {
        # Only what callPackage needs to auto-fill
        inherit (core) inputs sources;
        # Top-level helpers (no pkgs) merged with per-system helpers (use pkgs)
        libx = lib.recursiveUpdate cfg.libx (getSystem system).libx;
      })
    ]
    ++ cfg.overlays
    ++ (import "${cfg.paths.overlays}" core);

  mksPkgs =
    {
      system,
      extraNixpkgsArgs ? { },
    }:
    import inputs.nixpkgs-stable (
      {
        overlays = overlays system;
        config = cfg.nixpkgsConfig;
        localSystem = system;
      }
      // extraNixpkgsArgs
    );

  mkPkgs =
    {
      system,
      extraNixpkgsArgs ? { },
      extraNixpkgsStableArgs ? { },
    }:
    import inputs.nixpkgs (
      {
        config = cfg.nixpkgsConfig;
        localSystem = system;
        overlays = [
          (final: prev: {
            stable = mksPkgs {
              inherit system;
              extraNixpkgsArgs = extraNixpkgsStableArgs;
            };
          })
        ]
        ++ overlays system;
      }
      // extraNixpkgsArgs
    );

  build =
    system: extra:
    let
      pkgs = mkPkgs { inherit system; };

      # Top-level option (function of pkgs), so consumers don't need
      # `pkgs`/`base` as module args, which would cause infinite recursion
      extraFromPerSystem = cfg.extraBaseWithPkgs pkgs;

      own = {
        inherit
          pkgs
          mkBase
          mkPkgs
          mksPkgs
          forSystem
          ;
        inherit (pkgs) myPkgs libx;
        # Same instance as pkgs.stable, so nixpkgs-stable is imported once
        sPkgs = pkgs.stable;
        builder = cfg.builder // {
          inherit
            mkBase
            mkPkgs
            mksPkgs
            forSystem
            mkCoreBase
            ;
        };
        base = full;
      };

      full =
        assert disjoint "mkBase extraBase" extra (core // own);
        assert disjoint "extraBase" cfg.extraBase own;
        assert disjoint "extraBaseWithPkgs" extraFromPerSystem (core // own);
        core // extraFromPerSystem // extra // own;
    in
    full;

  mkBase =
    {
      system ? defaultSystem,
      extraBase ? { },
    }:
    build system extraBase;

  # Memoized per system by flake-parts
  forSystem = system: (getSystem system).base;

  # pkgs-free on purpose: a concrete `pkgs` here would silently be the one
  # for `defaultSystem` only. Go through `forSystem`/`mkBase` instead.
  topLevelBase = core // {
    inherit mkBase forSystem;
    builder = cfg.builder // {
      inherit
        mkBase
        mkPkgs
        mksPkgs
        forSystem
        mkCoreBase
        ;
    };
    base = topLevelBase;
  };
in
{
  options = {
    nixpkgsConfig = mkOption {
      type = types.attrs;
      default = { };
    };

    overlaysOfInputs = mkOption {
      type = types.listOf types.raw;
      default = [ ];
    };

    overlays = mkOption {
      type = types.listOf types.raw;
      default = [ ];
    };

    paths = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    # Pure helpers (no pkgs), e.g. `libx.foo = ...;`. Also holds the shared
    # types: libx.types.tree / libx.types.treeWith
    libx = mkOption {
      type = tree;
      default = { };
    };

    extraBase = mkOption {
      type = cfg.libx.types.tree;
      default = { };
    };

    extraArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    # Like `extraBase`, but a function of the built `pkgs`,
    # e.g. `pkgs: { tools.alias.less = "${pkgs.less}/bin/less"; }`.
    # Must not redefine built-in base keys (pkgs, myPkgs, builder, ...).
    extraBaseWithPkgs = mkOption {
      type = types.functionTo (types.lazyAttrsOf types.raw);
      default = _pkgs: { };
    };

    # pkgs-free base; get a per-system one via `base.forSystem` / `base.mkBase`
    base = mkOption {
      type = types.raw;
      readOnly = true;
    };

    perSystem = flake-parts-lib.mkPerSystemOption (
      { ... }:
      {
        options = {
          # Full base for this system (includes pkgs, sPkgs, myPkgs, libx)
          base = mkOption {
            type = types.raw;
            readOnly = true;
          };

          # Helpers that need pkgs: perSystem = { pkgs, ... }: { libx.foo = ...; };
          libx = mkOption {
            type = cfg.libx.types.tree;
            default = { };
          };

          # Packages from flake inputs' `packages.${system}.*`
          packagesOfInputs = mkOption {
            type = cfg.libx.types.tree;
            default = { };
          };
        };
      }
    );
  };

  config = {
    libx.types = {
      inherit tree;
      treeWith = mkTree;
    };

    base = topLevelBase;
    _module.args.base = cfg.base;
    extraBase.extraArgs = cfg.extraArgs;

    perSystem =
      { system, config, ... }:
      {
        base = build system { };
        _module.args = {
          inherit (config.base) pkgs;
          inherit (config) base;
        };
      };
  };
}
