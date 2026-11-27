{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config;

  names = attrs: lib.concatStringsSep ", " (lib.attrNames attrs);
  join = lib.concatStringsSep ", ";

  # Catalog names that cannot hold registered names in a selection
  reservedCatalogs = [
    "extra"
    "commons"
  ];

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
          Defined catalogs: ${names (removeAttrs catalogs [ "commons" ])}
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
              removeAttrs catalogs reservedCatalogs
            )
          )
          ++ catalogs.extra;
      }) modules
    );

  # ── tools.<domain>.<slot>.<backend> ──────────────────────────────────
  flattenTools =
    tools:
    lib.concatLists (
      lib.mapAttrsToList (
        domain: slots: lib.mapAttrsToList (slot: backend: { inherit domain slot backend; }) slots
      ) tools
    );

  # Features add up, so two of them choosing different backends is an error
  mergeFeatureTools =
    features:
    let
      bySlot = lib.groupBy (x: "${x.domain}.${x.slot}") (
        lib.concatMap (f: flattenTools f.tools) features
      );
      backendsOf = xs: lib.unique (map (x: x.backend) xs);
      conflicts = lib.filterAttrs (_: xs: lib.length (backendsOf xs) > 1) bySlot;
    in
    lib.throwIfNot (conflicts == { })
      "registry: features select different backends for the same slot: ${
        lib.concatStringsSep "; " (lib.mapAttrsToList (k: xs: "${k} = ${join (backendsOf xs)}") conflicts)
      }"
      (lib.foldl' lib.recursiveUpdate { } (map (f: f.tools) features));

  # Parts of a backend for frameworks the profile does not declare are dropped
  resolveTool =
    declared: domain: slot: backend:
    if backend == "none" then
      { }
    else
      let
        slots =
          cfg.tools.${domain} or (throw ''
            registry: unknown tool domain "${domain}".
            Defined domains: ${names cfg.tools}
          '');
        backends =
          slots.${slot} or (throw ''
            registry: unknown tool slot "${slot}" in tools.${domain}.
            Defined slots: ${names slots}
          '');
        selection =
          backends.${backend} or (throw ''
            registry: "${backend}" is not registered in tools.${domain}.${slot}.
            Registered: ${names backends}
          '');
      in
      resolveModules (lib.filterAttrs (fw: _: lib.elem fw declared) selection.modules);

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
    extra
    // {
      inherit name profile role;
      inherit (profileCfg) desktop;
      host = if host == null then null else host.name;
    }
    // roleFlags role;

  featuresOf =
    what: role: entity:
    map (
      n:
      let
        f =
          cfg.features.${n} or (throw ''
            registry: ${what}.features: unknown feature "${n}".
            Defined features: ${names cfg.features}
          '');
      in
      guard "feature '${n}'" f.requires role f
    ) (lib.unique entity.features);

  # Layer order, later wins for tools: defaults, features, role, desktop, profile
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

      features = featuresOf "profiles.${profile}" role profileChecked;
      upper = roleCfg ++ desktopCfg ++ [ profileChecked ];
      declared = lib.attrNames profileChecked.modules;

      selected = lib.foldl' lib.recursiveUpdate (lib.recursiveUpdate cfg.defaults.tools (
        mergeFeatureTools features
      )) (map (l: l.tools) upper);

      # Only frameworks the profile declares (even as `{ }`) get their commons
      commons = mergeByFramework (
        lib.mapAttrsToList (fw: _: {
          ${checkFramework fw} = cfg.modules.${fw}.commons or [ ];
        }) profileChecked.modules
      );

      toolModules = lib.concatLists (
        lib.mapAttrsToList (domain: slots: lib.mapAttrsToList (resolveTool declared domain) slots) selected
      );
    in
    mergeByFramework (
      [ commons ] ++ map (l: resolveModules l.modules) (features ++ upper) ++ toolModules
    );

  profilesResult = lib.mapAttrs (
    profile: _:
    resolve (mkMeta {
      name = profile;
      inherit profile;
    })
  ) cfg.profiles;

  # ── Static checks, expected to be empty (wire into flake checks) ─────
  entities =
    let
      tag =
        prefix: attrs:
        lib.mapAttrsToList (n: value: {
          name = "${prefix}${n}";
          inherit value;
        }) attrs;
    in
    tag "features." cfg.features
    ++ tag "desktops." cfg.desktops
    ++ tag "roles." cfg.roles
    ++ tag "profiles." cfg.profiles;

  # A tool choice: the domain and slot must exist and the backend be registered
  choiceErrors =
    where: domain: slot: backend:
    if backend == "none" then
      [ ]
    else if !(cfg.tools ? ${domain}) then
      [ "${where}: unknown tool domain" ]
    else if !(cfg.tools.${domain} ? ${slot}) then
      [ "${where}: unknown slot" ]
    else
      lib.optional (
        !(cfg.tools.${domain}.${slot} ? ${backend})
      ) "${where}: '${backend}' is not registered";

  toolChoiceErrors =
    prefix: tools:
    lib.concatLists (
      lib.mapAttrsToList (
        domain: slots:
        lib.concatLists (
          lib.mapAttrsToList (
            slot: backend: choiceErrors "${prefix}.${domain}.${slot}" domain slot backend
          ) slots
        )
      ) tools
    );

  # Checks for a `modules` selection, shared by entities and tool backends
  selectionErrors =
    where: modules:
    lib.concatLists [
      (lib.concatMap (
        fw: lib.optional (!lib.elem fw cfg.frameworks) "${where}.modules.${fw}: unknown framework"
      ) (lib.attrNames modules))

      # `commons` only lives in the registry, never in a selection
      (lib.concatLists (
        lib.mapAttrsToList (
          fw: catalogs:
          lib.optional (catalogs ? commons) "${where}.modules.${fw}.commons: 'commons' is a reserved catalog"
        ) modules
      ))

      (lib.concatLists (
        lib.mapAttrsToList (
          fw: catalogs:
          lib.concatLists (
            lib.mapAttrsToList (
              catalog: ns:
              lib.concatMap (
                n:
                lib.optional (
                  !((cfg.modules.${fw}.${catalog} or { }) ? ${n})
                ) "${where}.modules.${fw}.${catalog}: '${n}' is not registered"
              ) ns
            ) (removeAttrs catalogs reservedCatalogs)
          )
        ) modules
      ))
    ];

  registryErrors = lib.concatLists [
    (lib.concatMap (fw: lib.optional (!lib.elem fw cfg.frameworks) "modules.${fw}: unknown framework") (
      lib.attrNames cfg.modules
    ))

    (lib.concatMap (
      fw: lib.optional (cfg.modules.${fw} ? extra) "modules.${fw}.extra: 'extra' is a reserved catalog"
    ) (lib.attrNames cfg.modules))

    (lib.concatMap (e: selectionErrors e.name e.value.modules) entities)

    (lib.concatLists (
      lib.mapAttrsToList (
        domain: slots:
        lib.concatLists (
          lib.mapAttrsToList (
            slot: backends:
            lib.concatLists (
              lib.mapAttrsToList (
                backend: b: selectionErrors "tools.${domain}.${slot}.${backend}" b.modules
              ) backends
            )
          ) slots
        )
      ) cfg.tools
    ))

    (lib.concatMap (e: toolChoiceErrors "${e.name}.tools" e.value.tools) entities)

    (toolChoiceErrors "defaults.tools" cfg.defaults.tools)

    (lib.concatLists (
      lib.mapAttrsToList (
        domain: slots:
        lib.concatLists (
          lib.mapAttrsToList (
            s: backends:
            lib.optional (backends ? none) "tools.${domain}.${s}: 'none' is a reserved backend name"
          ) slots
        )
      ) cfg.tools
    ))

    # requires: every group must exist, even when no host role is known
    (lib.concatMap (
      e:
      lib.optionals (e.value ? requires) (
        map (g: "${e.name}.requires: unknown group '${g}'") (
          lib.filter (g: !lib.elem g cfg.roleGroups) (e.value.requires.groups ++ e.value.requires.notGroups)
        )
      )
    ) entities)

    (lib.concatLists (
      lib.mapAttrsToList (
        n: p:
        map (f: "profiles.${n}: unknown feature '${f}'") (lib.filter (f: !(cfg.features ? ${f})) p.features)
      ) cfg.profiles
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

  toolChoices = types.attrsOf (types.attrsOf types.str);

  toolsChoiceOption = mkOption {
    type = toolChoices;
    default = { };
    example = lib.literalExpression ''
      {
        desktop.launcher = "walker";
        desktop.display-manager = "none";
      }
    '';
    description = ''
      Exactly one backend per slot, as tools.<domain>.<slot> = "<backend>".
      "none" selects nothing. Later layers override earlier ones.
      Parts of a backend for frameworks the profile does not declare in `modules` are dropped.
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
      type = types.attrsOf (
        types.submodule {
          # Any other key is a catalog: name -> module
          freeformType = types.attrsOf (types.attrsOf types.deferredModule);
          options.commons = mkOption {
            type = types.listOf types.deferredModule;
            default = [ ];
            description = "Modules embedded in every profile that declares this framework, selected or not";
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          home.programs.fish = ./fish.nix;
          home.commons = [ ./base.nix ];
          nixos.services.vaultwarden = ./vaultwarden.nix;
        }
      '';
      description = ''
        Single-framework, additive entries: modules.<framework>.<catalog>.<name>.
        A value is any module: an attrset, a function or a path.
        The catalog `commons` is a list applied to every profile declaring the framework.
      '';
    };

    tools = mkOption {
      type = types.attrsOf (
        types.attrsOf (
          types.attrsOf (
            types.submodule {
              options.modules = modulesOption;
            }
          )
        )
      );
      default = { };
      example = lib.literalExpression ''
        {
          desktop.launcher.walker.modules.home.programs = [ "walker" ];
          desktop.display-manager.tuigreet.modules.nixos.services = [ "tuigreet" ];
          nixvim.picker.telescope.modules.nixvim.plugins = [ "telescope" ];
        }
      '';
      description = ''
        Mutually exclusive backends:
        tools.<domain>.<slot>.<backend>.modules.<framework>.<catalog> = [ names ].
        A domain is a free-form namespace (desktop, nixvim, ...), not a framework.
        A backend may span several frameworks; the parts for frameworks the
        profile does not declare in `modules` are dropped.
        Slots are chosen with `tools.<domain>.<slot>` in a desktop, role, feature or profile.
      '';
    };

    defaults.tools = mkOption {
      type = toolChoices;
      default = { };
      example = lib.literalExpression ''
        {
          nixvim = {
            picker = "telescope";
            completion = "blink-cmp";
          };
        }
      '';
      description = ''
        defaults.tools.<domain>.<slot> = "<backend>". Lowest layer: used when no
        other layer selects a backend for the slot. Only the parts for frameworks
        the profile declares in `modules` take effect.
      '';
    };

    features = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = selectionOptions // {
            requires = requiresOption;
          };
        }
      );
      default = { };
      description = ''
        Cross-framework concepts that add up. A profile pulls them in
        with profiles.<profile>.features = [ "<name>" ].
        `requires` is checked against the role of the host using the profile.
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

    registryErrors = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Static problems in the registry; expected to be empty.";
    };
  };

  config = {
    inherit resolve registryErrors;

    # `base.pure` and `builders` are declared in another module
    base.pure = {
      roles = roleNames;
      inherit groupsRole isInGroup;
      profiles = profilesResult;
    }
    // groupFns;

    builders = { inherit roleFlags roleFlagsModule mkMeta; };
  };
}
