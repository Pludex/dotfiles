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
  nodeType = types.oneOf [
    pkgSpecType
    (types.attrsOf nodeType)
  ];

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

  # Recursively collects packages configured with `ciBuild = true` into a flat attrset for CI.
  collectCiPackages =
    prefix: tree: builtTree:
    lib.foldl' lib.mergeAttrs { } (
      lib.mapAttrsToList (
        name: node:
        let
          key = if prefix == "" then name else "${prefix}.${name}";
          builtNode = builtTree.${name} or null;
        in
        if node ? path then
          if node.ciBuild && builtNode != null then { "${key}" = builtNode; } else { }
        else if builtins.isAttrs node && builtins.isAttrs builtNode then
          collectCiPackages key node builtNode
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
    # discover what to build, then `nix build .#ciPackages.<system>.<name>`
    # and push each result to Cachix. Other modules add to this by
    # setting `perSystem.ciPackages = { foo = ...; };` in their own
    # file - the module system merges separate files' definitions of
    # the same attrset as long as keys don't clash.
    (flake-parts-lib.mkTransposedPerSystemModule {
      name = "ciPackages";
      option = mkOption {
        type = types.lazyAttrsOf types.package;
        default = { };
        description = ''
          Packages registered by any module to be built by CI for this
          system and pushed to Cachix. Distinct from `packages` below -
          an explicit, opt-in registry, so a derivation can be built by
          CI without needing to be published as a `packages.<name>`
          flake output.
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
        ciPackages = collectCiPackages "" config.myPkgs base.myPkgs;
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
