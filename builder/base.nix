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

  # builder is safe to carry here as long as its functions take
  # base/pkgs as an argument (or read it via `final` inside an overlay)
  # instead of closing over the `pkgs` defined later in `build` - only
  # `pkgs` itself must never appear here, since overlays and paths.pkgs
  # are built from `core`:
  # pkgs -> overlays -> base(core).pkgs -> pkgs would recurse forever
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

  # Reconstructs `core` with a caller-supplied pkgs. Safe to call from
  # inside an overlay (pass `final`), since `core` never depends on
  # `pkgs` - that's the whole point of keeping it separate from `own`
  # in `build` below.
  #
  # This is NOT a full `base`: everything that lives in `own` (pkgs,
  # sPkgs, myPkgs, libx, mkBase, mkPkgs, mksPkgs, forSystem, the
  # builder overrides that wrap those, and the base = full self-ref)
  # is unavailable here on purpose - all of it only exists *after*
  # pkgs has finished building, which is exactly the stage an overlay
  # runs before. Needing any of that inside an overlay is a sign the
  # logic belongs in `perSystem` instead, where `base` is already
  # complete.
  mkCoreBase = { pkgs }: core // { inherit pkgs; };

  # packagesOfInputs comes from flake inputs' `packages.${system}.*`
  # output, so it's per-system; read it lazily from the perSystem
  # config of the system being built, rather than as a single
  # top-level value.
  overlays =
    system:
    cfg.overlaysOfInputs # overlays of flakes input
    ++ [
      (final: prev: prev // (getSystem system).packagesOfInputs)
      (final: prev: { base = core; })
      (
        final: prev:
        import cfg.paths.libx {
          pkgs = final;
          base = mkCoreBase { pkgs = final; };
        }
        # Only what callPackage needs to auto-fill in paths.pkgs
        // {
          inherit (core) inputs sources;
        }
      )
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

      # `extraBaseWithPkgs` is a TOP-LEVEL option (function of pkgs),
      # not a perSystem one. This matters: a perSystem consumer module
      # that only *sets* this option never needs to destructure `pkgs`
      # or `base` as a module-argument to do so - it just hands over a
      # plain lambda as data. That's what breaks the circularity that
      # a perSystem-scoped `extraBase` would invite: any perSystem
      # module written as `{ pkgs, ... }: { perSystem.extraBase = ...; }`
      # forced Nix to resolve `_module.args.pkgs` (= `config.base.pkgs`)
      # just to evaluate the module - but `config.base.pkgs` itself
      # depends on `extraBase` being fully evaluated first => infinite
      # recursion. Reading `cfg.extraBaseWithPkgs` here instead is a
      # plain top-level config lookup; it doesn't touch `_module.args`
      # at all, so no such cycle is possible from *this* mechanism.
      # (A consumer module can still shoot itself in the foot by
      # destructuring `pkgs`/`base` at its own signature for unrelated
      # reasons - that's on the consumer, not this module.)
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
        # base.base.base... all resolve to the same set
        base = full;
      };

      full =
        assert disjoint "mkBase extraBase" extra (core // own);
        assert disjoint "extraBase" cfg.extraBase own;
        assert disjoint "extraBaseWithPkgs" extraFromPerSystem (core // own);
        core // extraFromPerSystem // extra // own;
    in
    full;

  # Builds a fresh, fully-resolved base for one system (includes `pkgs`,
  # `sPkgs`, `myPkgs`, `libx`, ...). This is the only way to get a
  # concrete `pkgs` out of this module - always explicit about which
  # `system` you're asking for.
  mkBase =
    {
      system ? defaultSystem,
      extraBase ? { },
    }:
    build system extraBase;

  # Memoized per system by flake-parts
  forSystem = system: (getSystem system).base;

  # The top-level `base` (exposed as the `base` option / `_module.args.base`
  # for non-perSystem modules) is intentionally `pkgs`-free, same as `core`.
  # It's easy to assume this is "the" base the way `perSystem`'s `base` is,
  # but unlike that one it isn't recomputed per system - so if it carried a
  # concrete `pkgs` it would silently be `pkgs` for `defaultSystem` only,
  # even when called from a context building for another system. That bug
  # stays invisible as long as `cfg.systems` has one entry and only surfaces
  # once a second system is added - exactly the kind of thing that's hard to
  # track down later. Keeping `pkgs`/`sPkgs`/`myPkgs`/`libx` out entirely
  # forces every caller through `forSystem`/`mkBase` explicitly instead.
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

    extraBase = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };

    # Same purpose as `extraBase`, but for extras that need the
    # already-built `pkgs` (with all overlays applied) to compute
    # their value - e.g. `pkgs: { tools.alias.less = "${pkgs.less}/bin/less"; }`.
    # TOP-LEVEL (not per-system) on purpose: a single function is
    # reused for every system, called with that system's own `pkgs`
    # inside `build`. Consumer modules that set this option never need
    # `pkgs`/`base` as a module-argument to do so, which avoids the
    # circularity that a perSystem-scoped version of this option would
    # invite (see the comment on `extraFromPerSystem` above). Merged
    # into `base` after `pkgs`, alongside `own`, so it can see `pkgs`
    # but must not redefine any of base's built-in keys (pkgs, myPkgs,
    # builder, mkBase, ...).
    extraBaseWithPkgs = mkOption {
      type = types.functionTo (types.lazyAttrsOf types.raw);
      default = _pkgs: { };
    };

    # pkgs-free base: `core` plus `mkBase`/`forSystem` (and a `builder`
    # extended with them). Get a concrete, per-system `pkgs` via
    # `base.forSystem system` or `base.mkBase { inherit system; }`.
    base = mkOption {
      type = types.raw;
      readOnly = true;
    };

    perSystem = flake-parts-lib.mkPerSystemOption (
      { ... }:
      {
        options = {
          # Full base for this system: everything in the top-level `base`
          # plus `pkgs`, `sPkgs`, `myPkgs`, `libx`.
          base = mkOption {
            type = types.raw;
            readOnly = true;
          };

          # Packages sourced from flake inputs' `packages.${system}.*`
          # output. Per-system by nature, so it lives here rather than
          # at the top level.
          packagesOfInputs = mkOption {
            type = types.attrsOf types.package;
            default = { };
          };
        };
      }
    );
  };

  config = {
    base = topLevelBase;
    _module.args.base = cfg.base;

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
