{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  lookup =
    framework: catalog: name:
    let
      entries = cfg.modules.${framework}.${catalog} or { };
    in
    entries.${name} or (throw ''
      profiles: "${name}" is not registered in modules.${framework}.${catalog}.
      Registered: ${lib.concatStringsSep ", " (lib.attrNames entries)}
    '');

  # The key lets the module system dedupe an entry pulled in several times.
  entry = framework: catalog: name: {
    key = "modules:${framework}.${catalog}.${name}";
    imports = [ (lookup framework catalog name) ];
  };

  mergeByFramework = lib.zipAttrsWith (_: lib.concatLists);

  # selection -> { <framework> = [ module ]; }
  resolveSelection =
    sel:
    mergeByFramework [
      (lib.mapAttrs (
        framework: catalogs:
        lib.concatLists (
          lib.mapAttrsToList (catalog: names: map (entry framework catalog) (lib.unique names)) catalogs
        )
      ) sel.use)
      sel.extra
    ];

  resolveProfile =
    profileName: profile:
    let
      features = map (
        n:
        cfg.features.${n} or (throw ''
          profiles.${profileName}.features: unknown feature "${n}".
          Defined features: ${lib.concatStringsSep ", " (lib.attrNames cfg.features)}
        '')
      ) (lib.unique profile.features);
    in
    mergeByFramework (map resolveSelection (features ++ [ profile ]));

  selectionOptions = {
    use = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.str));
      default = { };
      example = lib.literalExpression ''
        {
          home.programs = [ "git" "fish" ];
          nixos.services = [ "openssh" ];
        }
      '';
      description = ''
        Entries of `modules` to enable, as use.<framework>.<catalog> = [ names ].
      '';
    };

    extra = mkOption {
      type = types.attrsOf (types.listOf types.deferredModule);
      default = { };
      example = lib.literalExpression ''
        { home = [ ./local.nix ({ ... }: { programs.bat.enable = true; }) ]; }
      '';
      description = ''
        One-off modules appended per framework, without registering them.
      '';
    };
  };
in
{
  options = {
    modules = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf types.deferredModule));
      default = { };
      example = lib.literalExpression ''
        {
          home.programs.git.programs.git.enable = true;
          home.programs.fish = { pkgs, ... }: { programs.fish.enable = true; };
          nixos.services.openssh = ./openssh.nix;
        }
      '';
      description = ''
        Registered as modules.<framework>.<catalog>.<name>.
        A value is any module: an attrset, a function or a path.
        Defining the same name more than once merges the definitions.
      '';
    };

    features = mkOption {
      type = types.attrsOf (types.submodule { options = selectionOptions; });
      default = { };
      example = lib.literalExpression ''
        {
          hermes = {
            use.nixos.services = [ "hermes" ];
            use.home.programs = [ "hermes" ];
          };
        }
      '';
      description = ''
        Large, self-contained concepts spanning several frameworks.
        A profile pulls them in with profiles.<profile>.features = [ "<name>" ].
      '';
    };

    profiles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "hermes" ];
              description = "Names of entries in the top-level `features` option.";
            };
          };
        }
      );
      default = { };
      description = ''
        Named selections of `modules` entries and features.
      '';
    };

    profilesResult = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.raw));
      readOnly = true;
      description = ''
        Resolved profiles: one module list per framework, ready for `imports`.
      '';
    };
  };

  config = {
    profilesResult = lib.mapAttrs resolveProfile cfg.profiles;
    base.pure.profiles = config.profilesResult;
  };
}
