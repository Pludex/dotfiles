{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  names = attrs: lib.concatStringsSep ", " (lib.attrNames attrs);
  join = lib.concatStringsSep ", ";

  # ── Roles and role groups ────────────────────────────────────────────
  roleNames = lib.attrNames cfg.roles;

  groupsRole = lib.genAttrs cfg.roleGroups (
    g: lib.attrNames (lib.filterAttrs (_: r: lib.elem g r.groups) cfg.roles)
  );

  cap = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
  flagName = group: "is${cap group}";

  checkRole =
    role:
    lib.throwIfNot (
      cfg.roles ? ${role}
    ) "registry: unknown role '${role}' (known: ${join roleNames})" role;

  checkGroup =
    group:
    lib.throwIfNot (
      groupsRole ? ${group}
    ) "registry: unknown role group '${group}' (known: ${join cfg.roleGroups})" group;

  isInGroup = group: role: lib.elem (checkRole role) groupsRole.${checkGroup group};

  flagsOf = f: lib.mapAttrs' (group: _: lib.nameValuePair (flagName group) (f group)) groupsRole;

  groupFns = flagsOf (group: role: isInGroup group role);

  # A null role (no host) gives all false
  roleFlags = role: flagsOf (group: role != null && isInGroup group role);

  roleFlagsModule.options = flagsOf (
    group:
    mkOption {
      type = types.bool;
      description = "Whether the role of the current host belongs to the '${group}' group";
    }
  );

  satisfies =
    role: req:
    role == null
    || (lib.all (g: isInGroup g role) req.groups && lib.all (g: !isInGroup g role) req.notGroups);

  guard =
    what: req: role: value:
    lib.throwIfNot (satisfies role req)
      "registry: ${what} requires groups [${join req.groups}] and none of [${join req.notGroups}], but role '${toString role}' does not match"
      value;

  # ── modules.<framework>.<catalog>.<name> ─────────────────────────────
  checkFramework =
    fw:
    lib.throwIfNot (lib.elem fw cfg.frameworks)
      "registry: unknown framework '${fw}' (known: ${join cfg.frameworks})"
      fw;

  lookup =
    framework: catalog: name:
    let
      catalogs = cfg.modules.${checkFramework framework} or { };
      entries =
        catalogs.${catalog} or (throw ''
          registry: catalog "${catalog}" does not exist in modules.${framework}.
          Defined catalogs: ${names catalogs}
        '');
    in
    entries.${name} or (throw ''
      registry: "${name}" is not registered in modules.${framework}.${catalog}.
      Registered: ${names entries}
    '');

  # The key lets the module system dedupe an entry pulled in several times
  entry = framework: catalog: name: {
    key = "modules:${framework}.${catalog}.${name}";
    imports = [ (lookup framework catalog name) ];
  };

  mergeByFramework = lib.zipAttrsWith (_: lib.concatLists);

  # modules.<framework>.<catalog> = [ names ], plus the special catalog `extra`
  resolveModules =
    modules:
    mergeByFramework (
      lib.mapAttrsToList (framework: catalogs: {
        ${checkFramework framework} =
          lib.concatLists (
            lib.mapAttrsToList (catalog: names': map (entry framework catalog) (lib.unique names')) (
              removeAttrs catalogs [ "extra" ]
            )
          )
          ++ catalogs.extra;
      }) modules
    );

  # ── tools: defined as <domain>.<slot>.<backend>, chosen as <slot> = <backend>
  # slot -> [ domains defining it ]; a slot must belong to exactly one domain
  slotOwners = lib.zipAttrsWith (_: lib.id) (
    lib.mapAttrsToList (domain: slots: lib.mapAttrs (_: _: domain) slots) cfg.tools
  );

  toFlat = lib.mapAttrs (slot: backend: { inherit slot backend; });

  flattenTools = tools: lib.attrValues (toFlat tools);

  # Features add up, so two of them choosing different backends is an error
  featureToolsFlat =
    features:
    let
      all = lib.concatMap (f: flattenTools f.tools) features;
      bySlot = lib.groupBy (x: x.slot) all;
      backendsOf = xs: lib.unique (map (x: x.backend) xs);
      conflicts = lib.filterAttrs (_: xs: lib.length (backendsOf xs) > 1) bySlot;
    in
    lib.throwIfNot (conflicts == { })
      "registry: features select different backends for the same slot: ${
        lib.concatStringsSep "; " (lib.mapAttrsToList (k: xs: "${k} = ${join (backendsOf xs)}") conflicts)
      }"
      (lib.foldl' (acc: f: acc // toFlat f.tools) { } features);

  domainOf =
    slot:
    let
      owners =
        slotOwners.${slot} or (throw ''
          registry: unknown tool slot "${slot}".
          Defined slots: ${names slotOwners}
        '');
    in
    lib.throwIf (lib.length owners > 1)
      "registry: tool slot \"${slot}\" is defined in several domains (${join owners}); slot names must be unique"
      (lib.head owners);

  resolveTool =
    { slot, backend }:
    if backend == "none" then
      { }
    else
      let
        domain = domainOf slot;
        backends = cfg.tools.${domain}.${slot};
        def =
          backends.${backend} or (throw ''
            registry: "${backend}" is not registered in tools.${domain}.${slot}.
            Registered: ${names backends}
          '');
      in
      resolveModules def.modules;

  # ── Meta and resolution ──────────────────────────────────────────────
  # host is the host record or null; with null, role and host are null
  mkMeta =
    {
      name,
      profile,
      host ? null,
      extra ? { },
    }:
    let
      profileCfg =
        cfg.profiles.${profile} or (throw ''
          registry: ${name}: unknown profile "${profile}".
          Defined profiles: ${names cfg.profiles}
        '');
      role = if host == null then null else host.role;
    in
    {
      inherit name profile role;
      inherit (profileCfg) desktop;
      host = if host == null then null else host.name;
    }
    // roleFlags role
    // extra;

  featuresOf =
    what: entity:
    map (
      n:
      cfg.features.${n} or (throw ''
        registry: ${what}.features: unknown feature "${n}".
        Defined features: ${names cfg.features}
      '')
    ) (lib.unique entity.features);

  # Layer order, later wins for tools: features, role, desktop, profile
  resolve =
    meta:
    let
      inherit (meta) profile role;
      profileCfg = cfg.profiles.${profile};
      desktopName = meta.desktop;
      desktopEntry =
        cfg.desktops.${desktopName} or (throw ''
          registry: unknown desktop "${desktopName}".
          Defined desktops: ${names cfg.desktops}
        '');
      desktopCfg = lib.optional (desktopName != null) (
        guard "desktop '${desktopName}'" desktopEntry.requires role desktopEntry
      );
      roleCfg = lib.optional (role != null) cfg.roles.${checkRole role};
      profileChecked = guard "profile '${profile}'" profileCfg.requires role profileCfg;

      features = featuresOf "profiles.${profile}" profileChecked;
      upper = roleCfg ++ desktopCfg ++ [ profileChecked ];
      selected = lib.foldl' (acc: l: acc // toFlat l.tools) (featureToolsFlat features) upper;
    in
    mergeByFramework (
      map (l: resolveModules l.modules) (features ++ upper) ++ map resolveTool (lib.attrValues selected)
    );

  # ── Static checks, expected to be empty (wire into flake checks) ─────
  entities =
    let
      tag =
        prefix: attrs:
        lib.mapAttrsToList (n: value: {
          name = "${prefix}${n}";
          inherit value;
        }) attrs;
      toolEntries = lib.concatLists (
        lib.mapAttrsToList (
          d: slots: lib.concatLists (lib.mapAttrsToList (s: backends: tag "tools.${d}.${s}." backends) slots)
        ) cfg.tools
      );
    in
    tag "features." cfg.features
    ++ tag "desktops." cfg.desktops
    ++ tag "roles." cfg.roles
    ++ tag "profiles." cfg.profiles
    ++ toolEntries;

  registryErrors = lib.concatLists [
    (lib.concatMap (fw: lib.optional (!lib.elem fw cfg.frameworks) "modules.${fw}: unknown framework") (
      lib.attrNames cfg.modules
    ))

    (lib.concatMap (
      fw: lib.optional (cfg.modules.${fw} ? extra) "modules.${fw}.extra: 'extra' is a reserved catalog"
    ) (lib.attrNames cfg.modules))

    (lib.concatMap (
      e:
      lib.concatMap (
        fw: lib.optional (!lib.elem fw cfg.frameworks) "${e.name}.modules.${fw}: unknown framework"
      ) (lib.attrNames e.value.modules)
    ) entities)

    (lib.concatMap (
      e:
      lib.concatLists (
        lib.mapAttrsToList (
          fw: catalogs:
          lib.concatLists (
            lib.mapAttrsToList (
              catalog: ns:
              lib.concatMap (
                n:
                lib.optional (
                  !((cfg.modules.${fw}.${catalog} or { }) ? ${n})
                ) "${e.name}.modules.${fw}.${catalog}: '${n}' is not registered"
              ) ns
            ) (removeAttrs catalogs [ "extra" ])
          )
        ) e.value.modules
      )
    ) entities)

    # Tool choices: the slot must exist, be unambiguous and have that backend
    (lib.concatMap (
      e:
      lib.concatMap (
        x:
        let
          owners = slotOwners.${x.slot} or [ ];
        in
        if x.backend == "none" || lib.length owners > 1 then
          [ ]
        else if owners == [ ] then
          [ "${e.name}.tools.${x.slot}: unknown slot" ]
        else
          lib.optional (
            !(cfg.tools.${lib.head owners}.${x.slot} ? ${x.backend})
          ) "${e.name}.tools.${x.slot}: '${x.backend}' is not registered"
      ) (flattenTools (e.value.tools or { }))
    ) entities)

    (lib.concatLists (
      lib.mapAttrsToList (
        s: ds:
        lib.optional (
          lib.length ds > 1
        ) "tools.${s}: slot is defined in several domains (${join ds}); slot names must be unique"
      ) slotOwners
    ))

    (lib.concatLists (
      lib.mapAttrsToList (
        d: slots:
        lib.concatLists (
          lib.mapAttrsToList (
            s: backends: lib.optional (backends ? none) "tools.${d}.${s}: 'none' is a reserved backend name"
          ) slots
        )
      ) cfg.tools
    ))

    (lib.concatLists (
      lib.mapAttrsToList (
        n: r:
        map (g: "roles.${n}: unknown group '${g}'") (lib.filter (g: !lib.elem g cfg.roleGroups) r.groups)
      ) cfg.roles
    ))

    (lib.concatLists (
      lib.mapAttrsToList (
        n: p:
        lib.optional (
          p.desktop != null && !(cfg.desktops ? ${p.desktop})
        ) "profiles.${n}: unknown desktop '${p.desktop}'"
      ) cfg.profiles
    ))

    (map (g: "roleGroups: '${g}' is not a valid flag name") (
      lib.filter (g: lib.match "[a-z][a-zA-Z0-9]*" g == null) cfg.roleGroups
    ))
  ];

  # ── Options ──────────────────────────────────────────────────────────
  modulesOption = mkOption {
    type = types.attrsOf (
      types.submodule {
        # Any other key is a catalog: a list of registered names
        freeformType = types.attrsOf (types.listOf types.str);
        options.extra = mkOption {
          type = types.listOf types.deferredModule;
          default = [ ];
          description = "Unregistered modules, appended as is";
        };
      }
    );
    default = { };
    example = lib.literalExpression ''
      {
        home.programs = [ "fish" "bat" ];
        home.extra = [ ./local.nix ];
        nixos.services = [ "vaultwarden" ];
      }
    '';
    description = "modules.<framework>.<catalog> = [ names ]; the catalog `extra` takes modules.";
  };

  toolsChoiceOption = mkOption {
    type = types.attrsOf types.str;
    default = { };
    example = lib.literalExpression ''{ launcher = "walker"; display-manager = "none"; }'';
    description = ''
      Exactly one backend per slot, as tools.<slot> = "<backend>". The domain is
      looked up from the slot, so slot names are unique across domains.
      "none" selects nothing. Later layers override earlier ones.
    '';
  };

  requiresOption = mkOption {
    type = types.submodule {
      options = {
        groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "The role must belong to all of these role groups";
        };
        notGroups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "The role must belong to none of these role groups";
        };
      };
    };
    default = { };
    description = "Role compatibility, checked when the meta has a role";
  };

  selectionOptions = {
    modules = modulesOption;
    tools = toolsChoiceOption;
  };
in
{
  options = {
    frameworks = mkOption {
      type = types.listOf types.str;
      default = [
        "home"
        "nixos"
        "rootHome"
        "nixvim"
      ];
      description = "Frameworks that modules can target";
    };

    modules = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf types.deferredModule));
      default = { };
      example = lib.literalExpression ''
        {
          home.programs.fish = ./fish.nix;
          nixos.services.vaultwarden = ./vaultwarden.nix;
        }
      '';
      description = ''
        Single-framework, additive entries: modules.<framework>.<catalog>.<name>.
        A value is any module: an attrset, a function or a path.
      '';
    };

    tools = mkOption {
      type = types.attrsOf (
        types.attrsOf (types.attrsOf (types.submodule { options.modules = modulesOption; }))
      );
      default = { };
      example = lib.literalExpression ''
        {
          desktop.launcher.walker.modules.home.programs = [ "walker" ];
          desktop.lock-screen.hyprlock.modules = {
            home.programs = [ "hyprlock" ];
            nixos.extra = [ ./hyprlock.pam.nix ];
          };
        }
      '';
      description = ''
        Mutually exclusive backends: tools.<domain>.<slot>.<backend>.modules.
        A backend may span several frameworks and is chosen with `tools.<slot>`
        in a desktop, role, feature or profile. Slot names are unique across domains.
      '';
    };

    features = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            app = mkOption {
              type = types.raw;
              default = null;
              description = "Pure data, forwarded to base.pure.apps.<feature>";
            };
          };
        }
      );
      default = { };
      description = ''
        Cross-framework concepts that add up. A profile pulls them in
        with profiles.<profile>.features = [ "<name>" ].
      '';
    };

    desktops = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            requires = requiresOption;
          };
        }
      );
      default = { };
      description = ''
        Mutually exclusive: each profile picks at most one.
        Its `tools` provide defaults that the profile can override.
      '';
    };

    roleGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "headless"
        "container"
      ];
      description = "Role groups; each one becomes an is<Group> flag";
    };

    roles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            groups = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Role groups this role belongs to";
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          desktop = { };
          server.groups = [ "headless" ];
          container.groups = [ "headless" "container" ];
        }
      '';
      description = "Machine kinds. Assigned to hosts by the host, never by the registry.";
    };

    profiles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            requires = requiresOption;
            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "hermes-agent" ];
              description = "Names of entries in the top-level `features` option.";
            };
            desktop = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Desktop of the profile, null when headless";
            };
          };
        }
      );
      default = { };
      description = "Named selections of modules, tools and features.";
    };

    resolve = mkOption {
      type = types.raw;
      readOnly = true;
      description = ''
        resolve meta -> { <framework> = [ module ]; }
        The meta comes from builders.mkMeta. Ready for `imports`.
      '';
    };

    profilesResult = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.raw));
      readOnly = true;
      description = "Profiles resolved without a host (no role), for older callers.";
    };

    registryErrors = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Static problems in the registry; expected to be empty.";
    };
  };

  config = {
    inherit resolve registryErrors;

    profilesResult = lib.mapAttrs (
      profile: _:
      resolve (mkMeta {
        name = profile;
        inherit profile;
      })
    ) cfg.profiles;

    base.pure = {
      roles = roleNames;
      inherit groupsRole isInGroup;
      profiles = config.profilesResult;
      apps = lib.mapAttrs (_: f: f.app) (lib.filterAttrs (_: f: f.app != null) cfg.features);
    }
    // groupFns;

    builders = { inherit roleFlags roleFlagsModule mkMeta; };
  };
}
