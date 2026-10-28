{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  # Handler can be either:
  #   - function: name: <bare path/string>
  #   - path: treated as a base dir, equivalent to name: dir + "/${name}"
  normalizeHandler = h: if builtins.isFunction h then h else (name: h + "/${name}");

  resolveEntry =
    category: subkey: handler: name:
    let
      bare = handler name;
      asFile = bare + ".nix";
      fileExists = builtins.pathExists asFile;
      dirExists = builtins.pathExists bare;
    in
    if fileExists && dirExists then
      throw ''
        profiles: ambiguous module for "${name}" (${category}.${subkey}):
        both ${toString asFile} and ${toString bare}/ exist - keep only one.
      ''
    else if fileExists then
      asFile
    else if dirExists then
      bare
    else
      throw ''
        profiles: no module found for "${name}" (${category}.${subkey}).
        Tried ${toString asFile} and ${toString bare}/ - neither exists.
      '';

  handlerFor =
    category: subkey:
    normalizeHandler (
      cfg.profilesImportHandlers.${category}.${subkey} or (throw ''
        profiles: profiles.*.${category}.${subkey} is used but
        profilesImportHandlers.${category}.${subkey} isn't defined.
      '')
    );

  resolveSubkey =
    category: subkey: names:
    map (resolveEntry category subkey (handlerFor category subkey)) names;

  # extraModules are already concrete modules -> pass through, skip the handler.
  resolveCategory =
    category: categoryCfg:
    let
      extraModules = categoryCfg.extraModules;
      subkeys = removeAttrs categoryCfg [ "extraModules" ];
    in
    extraModules ++ lib.concatLists (lib.mapAttrsToList (resolveSubkey category) subkeys);

  # Keys of a profile that are not categories
  reservedProfileKeys = [
    "modules"
    "features"
  ];

  resolveProfile =
    profileName: profileCfg:
    let
      moduleNames = lib.unique profileCfg.modules;
      featureNames = lib.unique profileCfg.features;

      registeredModules = map (
        n:
        cfg.modules.${n} or (throw ''
          profiles.${profileName}.modules: unknown module "${n}".
          Defined modules: ${lib.concatStringsSep ", " (lib.attrNames cfg.modules)}
        '')
      ) moduleNames;

      registeredFeatures = map (
        n:
        (cfg.features.${n} or (throw ''
          profiles.${profileName}.features: unknown feature "${n}".
          Defined features: ${lib.concatStringsSep ", " (lib.attrNames cfg.features)}
        '')
        ).modules
      ) featureNames;

      # category -> concatenated module list across all referenced modules and features
      registeredByCategory = lib.zipAttrsWith (_: lib.concatLists) (
        registeredModules ++ registeredFeatures
      );

      categories = removeAttrs profileCfg reservedProfileKeys;
      allCategories = lib.unique (lib.attrNames categories ++ lib.attrNames registeredByCategory);
    in
    lib.genAttrs allCategories (
      category:
      (registeredByCategory.${category} or [ ])
      ++ resolveCategory category (categories.${category} or { extraModules = [ ]; })
    );

  # Accepts a single module or a list of modules
  moduleList = types.coercedTo types.raw lib.toList (types.listOf types.raw);

  categorySubmodule = types.submodule {
    freeformType = types.attrsOf (types.listOf types.str);
    options.extraModules = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = ''
        Modules appended directly to this category's result, bypassing
        profilesImportHandlers. For one-off modules not worth a handler,
        e.g. profiles.foo.home.extraModules = [ ./local.nix ];
      '';
    };
  };

  featureSubmodule = types.submodule {
    options.modules = mkOption {
      type = types.attrsOf moduleList;
      default = { };
      example = lib.literalExpression ''
        {
          nixos = ./hermes/nixos.nix;
          home = [ ./hermes/home.nix ./hermes/skills.nix ];
        }
      '';
      description = ''
        Modules of this feature grouped by category (nixos, home, ...).
        Each value is a module or a list of modules.
      '';
    };
  };

  profileSubmodule = types.submodule {
    freeformType = types.attrsOf categorySubmodule;
    options.modules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "sops-os" ];
      description = ''
        Names of entries in the top-level `modules` option. For each name,
        every category defined there (nixos, home, ...) is added to this
        profile's result for that category.
        Note: "modules" and "features" are reserved and cannot be used as
        category names.
      '';
    };
    options.features = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "hermes" ];
      description = ''
        Names of entries in the top-level `features` option. Each feature's
        `modules.<category>` is added to this profile's result for that
        category, the same way as `modules`.
      '';
    };
  };
in
{
  options = {
    modules = mkOption {
      type = types.attrsOf (types.attrsOf moduleList);
      default = { };
      example = lib.literalExpression ''
        {
          sops-os = {
            nixos = ./sops-os/nixos.nix;
            home = ./sops-os/home.nix;
          };
        }
      '';
      description = ''
        Small reusable modules grouped as modules.<name>.<category>, where
        category is a target framework (nixos, home, nixvim, darwin, ...).
        Meant for glue that keeps several frameworks in sync. A profile pulls
        them in with profiles.<profile>.modules = [ "<name>" ].
      '';
    };

    features = mkOption {
      type = types.attrsOf featureSubmodule;
      default = { };
      example = lib.literalExpression ''
        {
          hermes.modules = {
            nixos = ./hermes/nixos.nix;
            home = ./hermes/home.nix;
          };
        }
      '';
      description = ''
        Large, self-contained concepts spanning several frameworks, defined
        as features.<name>.modules.<category>. Kept separate from `modules`
        so a feature can later grow new sibling options. A profile pulls them
        in with profiles.<profile>.features = [ "<name>" ].
      '';
    };

    profiles = mkOption {
      type = types.attrsOf profileSubmodule;
      default = { };
      description = ''
        Named bundles of entries, grouped by target category (home,
        nixos, nixvim, darwin, ...) and subkey (programs, services,
        apps, plugins, ...). Each entry is a name resolved via the
        matching profilesImportHandlers.<category>.<subkey>.

        Each category also accepts `extraModules`: a list of concrete
        modules appended as-is, bypassing the handler.

        `modules` and `features` list names from the top-level options of
        the same name, which are injected into the result per category.
      '';
    };

    profilesImportHandlers = mkOption {
      type = types.lazyAttrsOf (types.lazyAttrsOf types.raw);
      default = { };
      description = ''
        For each category.subkey pair used in `profiles`, a value that is
        either:
          - a function `name: <bare path/string>`, or
          - a path, shorthand for `name: path + "name"`
        The result is resolved to `<bare>.nix` or `<bare>/`.
      '';
    };

    profilesResult = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.raw));
      readOnly = true;
      description = ''
        `profiles`, resolved: registered modules, features, subkeys and
        extraModules flattened into one module list per category, ready to
        hand to that category's `imports` (home-manager, nixos, nixvim,
        darwin, ...).
      '';
    };
  };

  config = {
    profilesResult = lib.mapAttrs resolveProfile cfg.profiles;
    extraBase.profiles = config.profilesResult;
  };
}
