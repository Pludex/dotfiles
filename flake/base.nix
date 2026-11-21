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

  # ── Tree type ───────────────────────────────────────────────

  # Never walked into: non-attrsets, derivations, flake inputs, functors,
  # evalModules/nixosSystem results
  isLeaf =
    v:
    !(builtins.isAttrs v)
    || lib.isDerivation v
    || v ? outPath
    || v ? _type
    || v ? __functor
    || (v ? config && v ? options);

  mkTreeType =
    leafPred:
    let
      t = lib.mkOptionType {
        name = "tree";
        description = "leaf value or nested attribute set";
        descriptionClass = "noun";
        check = _: true;
        merge =
          loc: defs:
          if lib.any (d: leafPred d.value) defs then
            lib.mergeOneOption loc defs
          else
            (types.lazyAttrsOf t).merge loc defs;
      };
    in
    t;

  treeType = mkTreeType isLeaf;

  # Plain attrs are accepted and wrapped into `_: attrs`
  attrsOrPkgsFnType = types.coercedTo types.attrs (a: _: a) (
    types.functionTo (types.lazyAttrsOf types.raw)
  );

  # ── Merging ─────────────────────────────────────────────────

  # Deep merge that replaces leaves (derivations, inputs, ...) instead of merging them
  mergeTwo = lib.recursiveUpdateUntil (
    _: l: r:
    isLeaf l || isLeaf r
  );
  mergeAll = lib.foldl' mergeTwo { };

  # Shallow merge of nixpkgs configs; lists present on both sides are concatenated
  mergeConfig =
    a: b:
    a
    // b
    // lib.mapAttrs (n: v: a.${n} ++ v) (
      lib.filterAttrs (n: v: builtins.isList v && builtins.isList (a.${n} or null)) b
    );

  # ── Guards ──────────────────────────────────────────────────

  assertDisjoint =
    what: a: b:
    let
      clash = builtins.attrNames (builtins.intersectAttrs a b);
    in
    lib.assertMsg (
      clash == [ ]
    ) "base: ${what} redefines built-in key(s): ${lib.concatStringsSep ", " clash}";

  builtinKeys = {
    inherit inputs;
    inherit (cfg) paths libx;
    sources = inputs;
  };

  structuralKeys = lib.genAttrs [
    "base"
    "builders"
    "extraSpecialArgs"
  ] (_: null);

  # ── Channels ────────────────────────────────────────────────

  # Adding a channel = adding one line here
  channelSrcs = {
    unstable = inputs.nixpkgs;
    stable = inputs.nixpkgs-stable or null;
  };

  # `pkgs` itself is built from this channel; the others hang off it as `pkgs.<name>`
  mainChannel = "unstable";

  channelNames = builtins.attrNames channelSrcs;
  extraChannels = lib.remove mainChannel channelNames;
  enabledExtraChannels = lib.filter (n: cfg.nixpkgs.${n}.enable) extraChannels;
  enabledChannels = [ mainChannel ] ++ enabledExtraChannels;

  noRoot = {
    config = { };
    args = { };
    inputOverlays = [ ];
    overlays = [ ];
  };

  # Root values first, channel values on top
  channelSettings =
    name:
    let
      ch = cfg.nixpkgs.${name};
      root = if ch.inheritRoot then cfg.nixpkgs else noRoot;
    in
    {
      inherit (ch) src;
      config = mergeConfig root.config ch.config;
      args = root.args // ch.args;
      inputOverlays = root.inputOverlays ++ ch.inputOverlays;
      overlays = root.overlays ++ ch.overlays;
    };

  # ── pkgs-dependency probing ─────────────────────────────────

  # Any access throws, which is how pkgs-dependent leaves are detected
  pkgsPoison = throw "base: pkgs was accessed while probing for pkgs-free attrs";

  # "branch": recurse, "pure": pkgs-free leaf, "pkgs": needs pkgs
  # Functions and functors count as "pkgs" because their closures may capture the poisoned pkgs
  classify =
    v:
    let
      shape = builtins.tryEval (
        if builtins.isFunction v || (builtins.isAttrs v && v ? __functor) then
          "pkgs"
        else if isLeaf v then
          "leaf"
        else
          "branch"
      );
      # Attrs leaves (derivations, flake inputs) are only forced to WHNF
      forced = if builtins.isAttrs v then builtins.seq v true else builtins.deepSeq v true;
    in
    if !shape.success then
      "pkgs"
    else if shape.value == "leaf" then
      (if (builtins.tryEval forced).success then "pure" else "pkgs")
    else
      shape.value;

  # probe: built with poisoned pkgs, real: same function built with real pkgs
  splitTree =
    probe: real:
    let
      namesTry = builtins.tryEval (builtins.attrNames probe);
      kinds = lib.genAttrs namesTry.value (n: classify probe.${n});
      ofKind = k: lib.filterAttrs (_: kind: kind == k) kinds;
      branches = lib.mapAttrs (n: _: splitTree probe.${n} real.${n}) (ofKind "branch");
    in
    if !namesTry.success then
      {
        pure = { };
        full = real;
      }
    else
      {
        pure = lib.mapAttrs (_: s: s.pure) branches // lib.mapAttrs (n: _: probe.${n}) (ofKind "pure");
        full = lib.mapAttrs (_: s: s.full) branches // lib.mapAttrs (n: _: real.${n}) (ofKind "pkgs");
      };

  # Probes are evaluated once; `pure` needs no pkgs, `fullOf` realises the rest
  mkSplit =
    fns:
    let
      probes = map (f: f pkgsPoison) fns;
    in
    {
      pure = mergeAll (map (p: (splitTree p p).pure) probes);
      fullOf = pkgs: mergeAll (lib.zipListsWith (p: f: (splitTree p (f pkgs)).full) probes fns);
    };

  mixedSplit = mkSplit cfg.base.mixed;
  specialArgsSplit = mkSplit cfg.base.specialArgs;

  # ── Layers ──────────────────────────────────────────────────

  withPkgsOf = pkgs: mergeAll (map (f: f pkgs) cfg.base.withPkgs);
  specialArgsOf = pkgs: mergeAll (map (f: f pkgs) cfg.base.specialArgs);

  # Everything that exists once a pkgs is available, later layers win
  layersOf =
    pkgs:
    let
      mixedFull = mixedSplit.fullOf pkgs;
      withPkgs = withPkgsOf pkgs;
    in
    {
      inherit mixedFull withPkgs;
      merged = mergeTwo (mergeTwo pureBase mixedFull) withPkgs;
    };

  ctors = {
    inherit
      mkBase
      mkBaseFromPkgs
      mkPkgs
      mkChannel
      baseForSystem
      pkgsForSystem
      channelForSystem
      ;
  };

  # Spread flat into every base and also exposed as `base.builders`
  flatKeys = cfg.builders // ctors;

  # Must never depend on `pkgs`: pkgs -> overlays -> pureBase -> pkgs would recurse
  pureBase =
    assert assertDisjoint "builders" cfg.builders ctors;
    assert assertDisjoint "builders" flatKeys (builtinKeys // structuralKeys);
    assert assertDisjoint "base.pure" cfg.base.pure (builtinKeys // structuralKeys // flatKeys);
    assert assertDisjoint "base.mixed" mixedSplit.pure (
      builtinKeys // structuralKeys // flatKeys // cfg.base.pure
    );
    let
      self =
        builtinKeys
        // flatKeys
        // cfg.base.pure
        // mixedSplit.pure
        // {
          base = self;
          builders = flatKeys;
          extraSpecialArgs = specialArgsSplit.pure;
        };
    in
    self;

  # Safe to call from overlays (pass `final`): pkgs-dependent attrs stay lazy
  mkBaseFromPkgs =
    { pkgs }:
    (layersOf pkgs).merged
    // {
      inherit pkgs;
      extraSpecialArgs = specialArgsOf pkgs;
    };

  # ── pkgs construction ───────────────────────────────────────

  mkOverlays =
    system: settings:
    let
      sys = getSystem system;
    in
    settings.inputOverlays
    ++ [
      (_: _: sys.inputPackages)
      (_: _: {
        base = pureBase;
        # Only what callPackage needs to auto-fill
        inherit (pureBase) inputs sources;
        libx = mergeTwo cfg.libx sys.libx;
      })
    ]
    ++ settings.overlays
    ++ lib.optionals (cfg.paths ? overlays) (import cfg.paths.overlays pureBase);

  # `channelArgs.<name>` only applies to the main channel, where the other channels are attached
  mkChannel =
    {
      channel ? mainChannel,
      system,
      extraArgs ? { },
      channelArgs ? { },
    }:
    let
      settings = channelSettings channel;
      args = settings.args // extraArgs;
      attach =
        final: _:
        lib.genAttrs enabledExtraChannels (
          n:
          mkChannel {
            channel = n;
            inherit system;
            extraArgs = channelArgs.${n} or { };
          }
        )
        // {
          ${mainChannel} = final;
        };
    in
    assert lib.assertMsg (settings.src != null) "base: nixpkgs.${channel}.src is not set";
    import settings.src (
      {
        localSystem = system;
      }
      // removeAttrs args [
        "config"
        "overlays"
      ]
      // {
        config = mergeConfig settings.config (args.config or { });
        overlays =
          lib.optional (channel == mainChannel) attach
          ++ mkOverlays system settings
          ++ (args.overlays or [ ]);
      }
    );

  mkPkgs =
    {
      system,
      extraArgs ? { },
      channelArgs ? { },
    }:
    mkChannel { inherit system extraArgs channelArgs; };

  # ── Base construction ───────────────────────────────────────

  mkFullBase =
    system: extraAttrs: pkgsArgs:
    let
      pkgs = mkPkgs ({ inherit system; } // pkgsArgs);
      layers = layersOf pkgs;
      channels = lib.genAttrs enabledChannels (n: pkgs.${n});

      pkgsKeys = {
        inherit pkgs channels;
        inherit (pkgs) myPkgs libx;
        extraSpecialArgs = specialArgsOf pkgs;
        base = fullBase;
      }
      // lib.mapAttrs' (n: v: lib.nameValuePair "${n}Pkgs" v) channels;

      fullBase =
        assert assertDisjoint "builders" flatKeys pkgsKeys;
        assert assertDisjoint "mkBase extraAttrs" extraAttrs (pureBase // pkgsKeys);
        assert assertDisjoint "base.pure" cfg.base.pure pkgsKeys;
        assert assertDisjoint "base.mixed" layers.mixedFull pkgsKeys;
        assert assertDisjoint "base.withPkgs" layers.withPkgs pkgsKeys;
        mergeTwo layers.merged extraAttrs // pkgsKeys;
    in
    fullBase;

  # Reuses the memoized per-system base when there is nothing extra to add
  mkBase =
    {
      system,
      extraAttrs ? { },
      pkgsArgs ? { },
    }:
    if extraAttrs == { } && pkgsArgs == { } && builtins.elem system cfg.systems then
      baseForSystem system
    else
      mkFullBase system extraAttrs pkgsArgs;

  # Memoized per system by flake-parts
  baseForSystem = system: (getSystem system).base;
  pkgsForSystem = system: (baseForSystem system).pkgs;
  channelForSystem = name: system: (baseForSystem system).channels.${name};

  # ── Options ─────────────────────────────────────────────────

  sharedOptions = {
    config = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "nixpkgs `config`. At the root it is shared by every channel; in a channel it is merged on top (lists are concatenated)";
    };

    args = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = "Extra arguments for the nixpkgs import. `config` and `overlays` inside are merged, not replaced";
    };

    inputOverlays = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Overlays exported by flake inputs; applied first";
    };

    overlays = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Overlays applied after the built-in ones";
    };
  };

  channelOptions =
    name:
    sharedOptions
    // {
      src = mkOption {
        type = types.nullOr types.raw;
        default = channelSrcs.${name};
        description = "Flake input (or path) imported as this channel";
      };

      inheritRoot = mkOption {
        type = types.bool;
        default = true;
        description = "Start from the shared `nixpkgs.*` values";
      };
    }
    // lib.optionalAttrs (name != mainChannel) {
      enable = mkOption {
        type = types.bool;
        default = cfg.nixpkgs.${name}.src != null;
        defaultText = lib.literalExpression "config.nixpkgs.${name}.src != null";
        description = "Expose this channel as `pkgs.${name}` and `base.channels.${name}`";
      };
    };
in
{
  options = {
    nixpkgs = sharedOptions // lib.genAttrs channelNames channelOptions;

    paths = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = "Project paths; `overlays` is imported as `pureBase: [ overlay ]` when set";
    };

    builders = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = "User builders; spread flat into every base next to the built-in constructors and also exposed as `base.builders`";
    };

    # Also holds the shared types: libx.types.tree / libx.types.treeWith
    libx = mkOption {
      type = treeType;
      default = { };
      description = "Pure helpers (no pkgs)";
    };

    # None of these may redefine built-in base keys
    base = {
      pure = mkOption {
        type = treeType;
        default = { };
        description = "Attrs that never depend on pkgs; present in every base";
      };

      mixed = mkOption {
        type = types.listOf attrsOrPkgsFnType;
        default = [ ];
        description = "Functions `pkgs: attrs` split per leaf: pkgs-free leaves also land in the pure base";
      };

      withPkgs = mkOption {
        type = types.listOf attrsOrPkgsFnType;
        default = [ ];
        description = "Functions `pkgs: attrs` that only exist where a real pkgs does";
      };

      specialArgs = mkOption {
        type = types.listOf attrsOrPkgsFnType;
        default = [ ];
        description = "specialArgs for every configuration; entries may be `pkgs: attrs`";
      };
    };

    pureBase = mkOption {
      type = types.raw;
      readOnly = true;
      description = "pkgs-free base; get a per-system one via `baseForSystem` / `mkBase`";
    };

    perSystem = flake-parts-lib.mkPerSystemOption (
      _:
      {
        options = {
          base = mkOption {
            type = types.raw;
            readOnly = true;
            description = "Full base for this system (pkgs, channels, myPkgs, libx, ...)";
          };

          libx = mkOption {
            type = treeType;
            default = { };
            description = "Helpers that need pkgs";
          };

          inputPackages = mkOption {
            type = treeType;
            default = { };
            description = "Packages from flake inputs' `packages.<system>.*`";
          };
        };
      }
    );
  };

  config = {
    libx.types = {
      tree = treeType;
      treeWith = mkTreeType;
    };

    inherit pureBase;
    _module.args.base = cfg.pureBase;

    perSystem =
      { system, config, ... }:
      {
        base = mkFullBase system { } { };
        _module.args = {
          inherit (config.base) pkgs;
          inherit (config) base;
        };
      };
  };
}
