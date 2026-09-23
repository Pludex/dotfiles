{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  # Resolve one entry's handler output into a concrete module path.
  # The handler returns a bare path/string (no extension); `import`
  # already loads `default.nix` for a directory on its own, so a
  # resolved directory can be returned as-is.
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

  # A profile can reference a subkey with no matching handler (e.g. a
  # typo, or a category/subkey added to `profiles` before its handler
  # is written elsewhere); surface that here instead of an opaque
  # missing-attribute error deep inside mapAttrs.
  handlerFor =
    category: subkey:
    cfg.profilesImportHandlers.${category}.${subkey} or (throw ''
      profiles: profiles.*.${category}.${subkey} is used but
      profilesImportHandlers.${category}.${subkey} isn't defined.
    '');

  resolveSubkey =
    category: subkey: names:
    map (resolveEntry category subkey (handlerFor category subkey)) names;

  resolveCategory =
    category: subkeys: lib.concatLists (lib.mapAttrsToList (resolveSubkey category) subkeys);

  # No fixed list of categories anywhere: whatever categories a
  # profile actually uses (home, nixos, nixvim, darwin, ...) is what
  # gets resolved and shows up in profilesResult.
  resolveProfile = _profileName: lib.mapAttrs resolveCategory;
in
{
  options = {
    # profiles.<profileName>.<category>.<subkey> = [ entry names ]
    profiles = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.listOf types.str)));
      default = { };
      description = ''
        Named bundles of entries, grouped by target category (home,
        nixos, nixvim, darwin, ...) and subkey (programs, services,
        apps, plugins, ...). Each entry is a name resolved via the
        matching profilesImportHandlers.<category>.<subkey>.
      '';
    };

    # profilesImportHandlers.<category>.<subkey> = name: <bare path/string>
    profilesImportHandlers = mkOption {
      type = types.lazyAttrsOf (types.lazyAttrsOf types.raw);
      default = { };
      description = ''
        For each category.subkey pair used in `profiles`, a function
        mapping an entry name to a bare path (no .nix extension) -
        profiles.nix resolves that to `<bare>.nix` or `<bare>/`.
      '';
    };

    # profilesResult.<profileName>.<category> = [ resolved module paths ]
    profilesResult = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.raw));
      readOnly = true;
      description = ''
        `profiles`, resolved: subkeys flattened into one module list
        per category, ready to hand to that category's `imports`
        (home-manager, nixos, nixvim, darwin, ...).
      '';
    };
  };

  config = {
    profilesResult = lib.mapAttrs resolveProfile cfg.profiles;
    extraBase.profiles = config.profilesResult;
  };
}
