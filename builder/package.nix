{
  lib,
  flake-parts-lib,
  getSystem,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  # Submodule defining the schema for individual package declarations.
  pkgSpecType = types.submodule {
    options = {
      path = mkOption {
        type = types.path;
        description = "Path to the package source file or directory passed to `callPackage`.";
      };

      extraArgs = mkOption {
        type = types.attrsOf types.raw;
        default = { };
        description = "Additional arguments forwarded to `final.callPackage`.";
      };

      ciBuild = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to include this package in `ciPackages` output for CI builds.";
      };
    };
  };

  # Recursive type enabling hierarchical nested attribute definitions (e.g. `a.b = { path = ...; };`).
  #
  # NOTE: this is a hand-rolled type rather than `types.oneOf [pkgSpecType (types.attrsOf nodeType)]`.
  # `types.submodule`'s `check` is permissive (basically just `isAttrs`), so with `oneOf`/`either`,
  # which picks the first type for which *all* definitions pass `check`, `pkgSpecType` always wins -
  # every node, including ones meant as nested namespaces, gets coerced into a leaf package spec and
  # any nested attribute under it fails with "option does not exist". Instead we disambiguate leaf vs.
  # namespace explicitly by checking for the `path` key, mirroring what `buildMyPkgs` /
  # `collectCiPackages` below already do.
  nodeType = lib.mkOptionType {
    name = "packageTreeNode";
    description = "package specification or nested attribute set thereof";
    descriptionClass = "noun";
    check =
      x:
      builtins.isAttrs x
      && (if x ? path then pkgSpecType.check x else lib.all nodeType.check (builtins.attrValues x));
    merge =
      loc: defs:
      let
        isLeaf = lib.any (d: d.value ? path) defs;
      in
      if isLeaf then pkgSpecType.merge loc defs else (types.attrsOf nodeType).merge loc defs;
  };

  # Recursively instantiates package derivations in the overlay using `final.callPackage`.
  buildMyPkgs =
    final: tree:
    lib.mapAttrs (
      name: node:
      if node ? path then
        final.callPackage node.path node.extraArgs
      else if builtins.isAttrs node then
        buildMyPkgs final node
      else
        throw "package.nix: invalid package specification at attribute '${name}'"
    ) tree;

  # Recursively collects packages configured with `ciBuild = true`, preserving the same nested
  # shape as `myPkgs` (e.g. `ciPackages.vimPlugins.treesitter-kanata`, not a flattened
  # `ciPackages."vimPlugins.treesitter-kanata"` dotted-string key). Empty subtrees (no leaf under
  # them has `ciBuild = true`) are dropped entirely so they don't show up as empty attrsets.
  #
  # NOTE: because this returns a *nested* attrset rather than a flat one, CI discovery can no
  # longer just do `nix eval .#ciPackages.<system> --apply builtins.attrNames` and build each
  # name directly - that only sees the top-level keys, and building one of those may yield a
  # sub-attrset rather than a derivation. CI needs to walk the tree recursively (checking
  # `node.type or null == "derivation"` at each leaf) to discover full paths, then build each
  # with `nix build .#ciPackages.<system>.<a>.<b>...` (or eval-and-`nix-build` on the derivation
  # directly rather than shelling out per path).
  collectCiPackages =
    tree: builtTree:
    lib.foldl' lib.mergeAttrs { } (
      lib.mapAttrsToList (
        name: node:
        let
          builtNode = builtTree.${name} or null;
        in
        if node ? path then
          if node.ciBuild && builtNode != null then { "${name}" = builtNode; } else { }
        else if builtins.isAttrs node && builtins.isAttrs builtNode then
          let
            sub = collectCiPackages node builtNode;
          in
          if sub == { } then { } else { "${name}" = sub; }
        else
          { }
      ) tree
    );
in
{
  imports = [
    # Declares perSystem.<system>.ciPackages AND mirrors it as a real
    # top-level flake output ciPackages.<system>.<name>, so CI can do
    # `nix eval .#ciPackages.<system> --apply builtins.attrNames` to
    # discover top-level entries, then walk into nested ones and build
    # each leaf derivation found (see the note above `collectCiPackages`),
    # pushing each result to Cachix. Other modules add to this by
    # setting `perSystem.ciPackages = { foo = ...; };` in their own
    # file - the module system merges separate files' definitions of
    # the same attrset as long as keys don't clash.
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "ciPackages";
      option = mkOption {
        type = types.lazyAttrsOf types.raw;
        default = { };
        description = ''
          Packages registered by any module to be built by CI for this
          system and pushed to Cachix. Distinct from `packages` below -
          an explicit, opt-in registry, so a derivation can be built by
          CI without needing to be published as a `packages.<name>`
          flake output. Nested the same way as `myPkgs` (not flattened
          into dotted-string keys).
        '';
      };
      file = ./package.nix;
    })
  ];

  options = {
    # Declarative hierarchical specification for custom flake packages.
    myPkgs = mkOption {
      type = types.attrsOf nodeType;
      default = { };
      description = ''
        Hierarchical attribute set of package specifications. Each leaf package requires
        `path`, with optional `extraArgs` (defaults to `{}`) and `ciBuild` (defaults to `true`).
      '';
    };
  };

  config = {
    # Registers custom packages overlay into base.nix overlay pipeline.
    overlays = [
      (final: prev: {
        myPkgs = lib.recursiveUpdate (prev.myPkgs or { }) (buildMyPkgs final config.myPkgs);
      })
    ];

    perSystem =
      { base, ... }:
      {
        # Full (unstable) package set, browsable via `nix search`/
        # `nix build .#legacyPackages.<system>.<name>` per the usual
        # dual-channel flake convention.
        legacyPackages = base.pkgs;

        # The myPkgs.<profile> packages baked in by the overlay chain
        # (see base.pkgs.myPkgs), published as the main `packages`
        # flake output.
        packages = base.myPkgs;

        # Collects packages from `myPkgs` where `ciBuild = true` for CI evaluation.
        # Nested the same way as `myPkgs` - e.g. build a single leaf directly with
        # `nix build .#ciPackages.<system>.vimPlugins.treesitter-kanata`.
        ciPackages.myPkgs = collectCiPackages config.myPkgs base.myPkgs;
      };
  };

  # NOTE on why this is `mkPkgsFor` and not `config.flake.__functor`:
  #
  # `config.flake` is a submodule with a freeform type, and the
  # module system has to inspect every key assigned to it (packages,
  # legacyPackages, ...) to type-check/merge the final `flake`
  # output. A `__functor` key is special-cased by Nix itself (used to
  # make an attrset callable), and having one land inside a freeform
  # submodule's config can make the module system try to evaluate it
  # as part of that inspection - which here calls `getSystem`, which
  # itself needs `config` to resolve, which needs `config.flake`
  # fully built first: `config.flake -> __functor -> getSystem ->
  # config -> config.flake`, an infinite loop ("infinite recursion
  # encountered", surfaced through call-flake.nix's `result = ... //
  # outputs`).
  #
  # A plain named attribute sidesteps this entirely: it's just a
  # function value like any other flake output (packages,
  # nixosConfigurations, ...), never treated specially by the module
  # system, so it can safely close over `getSystem`/`config`.
  #
  # Usage: (builtins.getFlake "path:.").mkPkgsFor { system = "x86_64-linux"; }
  config.flake.mkPkgsFor =
    args:
    let
      # Fail loudly rather than silently defaulting to some arch - a
      # wrong system here would build a pkgs instance for the wrong
      # platform and only surface as a mismatch much later.
      system = args.system or (throw "flake.mkPkgsFor: `system` is required");
      args' = removeAttrs args [ "system" ];
    in
    # `mkPkgs` itself doesn't care which system's `base` it's pulled
    # from - it only uses the `system` argument passed to it below -
    # so we always fetch it via the first configured system, letting
    # `system` here be anything (including systems not listed in
    # `config.systems`, since mkPkgs -> `import inputs.nixpkgs` has
    # no such restriction).
    (getSystem (builtins.head config.systems)).base.builder.mkPkgs {
      inherit system;
      # Same extra args forwarded to both the unstable and the
      # `pkgs.stable` channel. If `args'` contains `overlays` or
      # `config`, note that mkPkgs/mksPkgs merge it in with `//`
      # (right-hand side wins), so it *replaces* rather than extends
      # this flake's own overlay chain/nixpkgs config for that
      # instance - myPkgs, packagesOfInputs, paths.libx, etc. would
      # be lost from the resulting pkgs unless re-added by the caller.
      extraNixpkgsArgs = args';
      extraNixpkgsStableArgs = args';
    };
}
