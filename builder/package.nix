{
  lib,
  flake-parts-lib,
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

  # Hand-rolled instead of `types.oneOf [ pkgSpecType (types.attrsOf nodeType) ]`:
  # `types.submodule`'s `check` is permissive (basically `isAttrs`), so `oneOf`
  # would always pick `pkgSpecType` and fail on nested namespaces.
  # Leaf vs. namespace is decided by the presence of the `path` key instead.
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

  # Collects packages with `ciBuild = true`, keeping the nested shape of `myPkgs`
  # (e.g. `ciPackages.vimPlugins.treesitter-kanata`). Empty subtrees are dropped.
  #
  # Because the result is nested, CI discovery must walk the tree recursively
  # (checking `type or null == "derivation"` at each leaf) and build each leaf with
  # `nix build .#ciPackages.<system>.<a>.<b>...`.
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
    # Declares perSystem.<system>.ciPackages and mirrors it as the flake output
    # ciPackages.<system>.<name>. Other modules add to it with
    # `perSystem.ciPackages = { foo = ...; };`.
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "ciPackages";
      option = mkOption {
        type = config.libx.types.tree;
        default = { };
        description = ''
          Packages registered by any module to be built by CI for this
          system and pushed to Cachix. Distinct from `packages`: an explicit,
          opt-in registry, so a derivation can be built by CI without being
          published as a `packages.<name>` output. Nested the same way as
          `myPkgs`.
        '';
      };
      file = ./package.nix;
    })
  ];

  options = {
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
    # Shared by every channel, so `pkgs.stable.myPkgs` exists too
    nixpkgs.overlays = [
      (final: prev: {
        myPkgs = lib.recursiveUpdate (prev.myPkgs or { }) (buildMyPkgs final config.myPkgs);
      })
    ];

    perSystem =
      { base, ... }:
      {
        legacyPackages = base.pkgs;
        packages = base.myPkgs;
        ciPackages.myPkgs = collectCiPackages config.myPkgs base.myPkgs;
      };

    # Kept as a plain named attribute rather than `flake.__functor`: a `__functor`
    # inside the freeform `flake` submodule makes the module system call `getSystem`
    # while building `config.flake`, which loops forever.
    #
    # Usage: (builtins.getFlake "path:.").mkPkgsFor { system = "x86_64-linux"; }
    flake.mkPkgsFor =
      args:
      let
        system = args.system or (throw "flake.mkPkgsFor: `system` is required");
        args' = removeAttrs args [ "system" ];
      in
      # `mkPkgs` only needs `system`, so it works for systems outside `config.systems` too.
      # `config` and `overlays` in `args'` are merged with the flake's own
      # (lists concatenated, overlays appended), not replaced.
      config.pureBase.builders.mkPkgs {
        inherit system;
        extraArgs = args';
        # Same extra args for every other channel (anything with a `src` option)
        channelArgs = lib.mapAttrs (_: _: args') (lib.filterAttrs (_: v: v ? src) config.nixpkgs);
      };
  };
}
