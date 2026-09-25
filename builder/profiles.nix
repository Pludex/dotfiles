{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  # Handler can be either:
  #   - function: name: <bare path/string>  (as before)
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

  resolveProfile = _profileName: lib.mapAttrs resolveCategory;

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
in
{
  options = {
    profiles = mkOption {
      type = types.attrsOf (types.attrsOf categorySubmodule);
      default = { };
      description = ''
        Named bundles of entries, grouped by target category (home,
        nixos, nixvim, darwin, ...) and subkey (programs, services,
        apps, plugins, ...). Each entry is a name resolved via the
        matching profilesImportHandlers.<category>.<subkey>.

        Each category also accepts `extraModules`: a list of concrete
        modules appended as-is, bypassing the handler.
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
        `profiles`, resolved: subkeys and extraModules flattened into
        one module list per category, ready to hand to that category's
        `imports` (home-manager, nixos, nixvim, darwin, ...).
      '';
    };
  };

  config = {
    profilesResult = lib.mapAttrs resolveProfile cfg.profiles;
    extraBase.profiles = config.profilesResult;
  };
}
