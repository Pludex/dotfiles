# AGENTS.md

Guide for agents working on the flake-parts layer in `flake/` and the modules built on it
(`base.nix`, `registry.nix`, `hosts.nix`, `home.nix`, `nixos.nix`, `nixvim.nix`, `package.nix`).

## Overview

`flake/base.nix` builds a shared attribute set called `base` that every other module consumes.
It exists in two forms:

- **`pureBase`**: never depends on `pkgs`. Available at the flake level as
  `config.pureBase` and as `_module.args.base` at the top level.
- **Full base**: `pureBase` plus everything that needs a real `pkgs`. Built per system
  and available as `perSystem.base` / `_module.args.base` inside `perSystem`.

The root `settings.nix` only holds data (identity, paths, theme, default tools) and assigns
it to the `base.*` and `paths` options. The mechanism that processes those options is
`flake/base.nix`. Do not put logic in `settings.nix`.

## Layout

| Path                                                  | Role                                                       |
| ----------------------------------------------------- | ---------------------------------------------------------- |
| `flake/`                                              | flake-parts modules: options, resolution and glue          |
| `settings.nix`                                        | Data assigned to `base.*` and `paths`                      |
| `home/`, `nixos/`, `nixvim/`, `desktops/`, `modules/` | Modules of other frameworks, selected through the registry |
| `hosts/`                                              | Host instances (values for `hosts.<name>`)                 |
| `profiles/`                                           | Profile instances (values for `profiles.<name>`)           |

## Hard rules

1. **`pureBase` must never touch `pkgs`.** The chain
   `pkgs -> overlays -> pureBase -> pkgs` would recurse infinitely.
2. **Never use `pkgsForSystem`, `baseForSystem` or `channelForSystem` inside overlays
   or inside `pureBase`.** Overlays use `final`/`prev`. If an overlay needs a base, use
   `config.pureBase.builders.mkBaseFromPkgs { pkgs = final; }`.
3. **Do not call `mkPkgs` or `mkBase` per host or per module** when the default is
   enough. Use `baseForSystem` / `pkgsForSystem` so one nixpkgs instance per system is
   shared. `mkBase { system; }` already reuses the memoized base when `extraAttrs` and
   `pkgsArgs` are empty and `system` is in `config.systems`.
4. **Do not redefine built-in keys.** Assertions fail at eval time when `builders`,
   `base.pure`, `base.mixed`, `base.withPkgs` or `extraAttrs` clash with built-in keys.
   Keys contributed by other flake modules count as built-in:
   - builders: `roleFlags`, `roleFlagsModule`, `desktopOf`, `host`, `hostModules`,
     `mkHomeStandalone`, `mkHomeNonStandalone`, `mkNixos`, `mkNixosModules`,
     `mkNixosSpecialArgs`, `nixosModulesOf`, `nixosSpecialArgsOf`, `mkNvimPkg`,
     `mkNixvimConfig`
   - `base.pure`: `roles`, `groupsRole`, `isInGroup`, `profiles`, `apps`, `configMeta`
     and every `is<Group>`
5. **Breaking the API is acceptable** when it makes names or structure clearer, but
   update every consumer in the same change.

## Options

### Base inputs

| Option             | Type                            | Purpose                                                                               |
| ------------------ | ------------------------------- | ------------------------------------------------------------------------------------- |
| `base.pure`        | `tree`                          | Attrs that never depend on pkgs; present in every base                                |
| `base.mixed`       | `listOf (attrs \| pkgs: attrs)` | Split per leaf: pkgs-free leaves go into `pureBase`, the rest only into the full base |
| `base.withPkgs`    | `listOf (attrs \| pkgs: attrs)` | Only present in the full base                                                         |
| `base.specialArgs` | `listOf (attrs \| pkgs: attrs)` | Becomes `base.extraSpecialArgs`                                                       |

### Registry and hosts

| Option           | Purpose                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------ |
| `frameworks`     | Frameworks that modules can target (`home`, `nixos`, `rootHome`, `nixvim`)                       |
| `modules`        | `modules.<framework>.<catalog>.<name>`: registered, additive, single-framework modules           |
| `tools`          | `tools.<domain>.<slot>.<backend>.modules`: mutually exclusive backends, one per slot             |
| `features`       | Cross-framework concepts that add up; pulled in by `profiles.<name>.features`                    |
| `desktops`       | Mutually exclusive; each configuration picks one; its `tools` are defaults                       |
| `roleGroups`     | Role groups; each one becomes an `is<Group>` flag                                                |
| `roles`          | Attrset of machine kinds (`roles.<name>.groups`); assigned to hosts by `hosts`, not here         |
| `profiles`       | Named selections of modules, tools, features and a default desktop                               |
| `resolve`        | Read-only; `resolve { profile, desktop ? null, role ? null }` -> `{ <framework> = [ module ]; }` |
| `profilesResult` | Read-only; profiles resolved with their default desktop and `role = null`                        |
| `registryErrors` | Read-only; static problems in the registry, expected to be `[ ]`                                 |
| `hosts`          | `hosts.<name>` with `extends`, `withHome`, `system`, `role`, `gpus`, `modules`                   |

### Configurations

Each one maps a name to a profile (and optionally a host and a desktop) and produces a flake output.

| Option          | Output                         | Fields                                                    |
| --------------- | ------------------------------ | --------------------------------------------------------- |
| `nixos.<name>`  | `nixosConfigurations.<name>`   | `host`, `profile`, `desktop`, `withRoot`, `extraModules`  |
| `home.<name>`   | `homeConfigurations.<name>`    | `host`, `profile`, `desktop`, `extraModules`              |
| `nixvim.<name>` | `nixvimConfigurations.<system>.<name>` and `myPkgs.<name>` | `host` (nullable), `extraModules`  |

- `host` defaults to the configuration name (nixvim: `null` means host-independent).
- `desktop` defaults to the profile's desktop.
- `nixosModules`, `homeModules` and `nixvimModules` are added to every configuration of that kind.

### Other options

| Option                    | Purpose                                                                           |
| ------------------------- | --------------------------------------------------------------------------------- |
| `builders`                | User builders; spread flat into every base and also at `base.builders`            |
| `libx`                    | Pure helpers (no pkgs); also holds `libx.types.tree` / `libx.types.treeWith`      |
| `paths`                   | Project paths; `paths.overlays`, when set, is imported as `pureBase: [ overlay ]` |
| `pureBase`                | Read-only; the pkgs-free base                                                     |
| `perSystem.base`          | Read-only; full base for that system                                              |
| `perSystem.libx`          | Helpers that need pkgs                                                            |
| `perSystem.inputPackages` | `packages.<system>.*` from flake inputs, exposed on `pkgs`                        |
| `myPkgs`                  | Tree of package specs (`path`, `extraArgs`, `ciBuild`)                            |
| `perSystem.ciPackages`    | Flat attrset of packages built by CI; mirrored as `ciPackages.<system>`           |

### nixpkgs

Root values are shared by all channels; each channel inherits them (unless
`inheritRoot = false`) and layers its own values on top.

| Option                                                   | Purpose                                                           |
| -------------------------------------------------------- | ----------------------------------------------------------------- |
| `nixpkgs.{config,args,inputOverlays,overlays}`           | Shared by every channel                                           |
| `nixpkgs.<channel>.{config,args,inputOverlays,overlays}` | Per channel, merged on top of root                                |
| `nixpkgs.<channel>.src`                                  | Flake input (default: `inputs.nixpkgs` / `inputs.nixpkgs-stable`) |
| `nixpkgs.<channel>.inheritRoot`                          | Whether to start from the root values                             |
| `nixpkgs.<non-main channel>.enable`                      | Exposes `pkgs.<channel>` and `base.channels.<channel>`            |

Merge semantics: `config` is merged shallowly and lists present on both sides are
concatenated; `args` is a shallow merge (channel wins); overlays are root first, then channel.

Channels are defined by `channelSrcs` in `flake/base.nix`; `unstable` is `mainChannel` and
backs `pkgs`. **Adding a channel is one line in `channelSrcs`**. The options,
`pkgs.<name>`, `base.channels.<name>` and `base.<name>Pkgs` are generated from it.

## Base contents

**`pureBase`**: `inputs`, `sources` (same as `inputs`), `paths`, `libx`, all `builders`
(flat), `base.pure` (including the keys other flake modules add), pkgs-free part of
`base.mixed`, `builders` (namespaced), `extraSpecialArgs` (pkgs-free part), `base` (itself).

**Full base** adds, later wins: pkgs-dependent part of `base.mixed`, `base.withPkgs`,
`extraAttrs`, then fixed keys: `pkgs`, `channels`, `<channel>Pkgs`, `myPkgs`, `libx`,
`extraSpecialArgs` (resolved with real pkgs), `base`.

**Builders** (always available at `base.builders.*` and flat): `mkBase`,
`mkBaseFromPkgs`, `mkPkgs`, `mkChannel`, `baseForSystem`, `pkgsForSystem`,
`channelForSystem`, plus everything listed in rule 4 and anything the user defines in `builders`.

**Inside `pkgs`**: `pkgs.<channel>`, `pkgs.base` (= `pureBase`), `pkgs.inputs`,
`pkgs.sources`, `pkgs.libx`, and everything from `inputPackages`.

## Registry

`registry.nix` resolves a profile into module lists per framework.

- **Layers**: features first, then role, desktop and profile. For `tools`, the later layer
  wins; two features choosing different backends for the same slot is an error.
- **`modules`**: `modules.<framework>.<catalog> = [ names ]` selects registered entries.
  The reserved catalog `extra` takes unregistered modules as is.
- **`tools`**: `tools.<domain>.<slot> = "<backend>"`; `"none"` selects nothing and is a
  reserved backend name.
- **`requires`** (on desktops and profiles): `groups` must all contain the role,
  `notGroups` must contain none. Checked only when `role` is given to `resolve`.
- **Role flags**: every entry of `roleGroups` becomes `is<Group>`.
  `roleFlags role` returns all flags for a role (all `false` for `null`).
  `roleFlagsModule` declares the matching options.
- **`base.pure` contributions**: `roles` (list of names), `groupsRole`, `isInGroup`,
  `profiles` (= `profilesResult`), `apps` (from `features.<name>.app`) and the `is<Group>`
  functions.
- **`registryErrors`** must be `[ ]`; wire it into flake `checks`.

## Configuration modules

All three build a `meta` attrset per configuration and publish it as
`base.pure.configMeta.<kind>.<name>`:
`{ name, profile, desktop, host, role }` plus every `is<Group>` flag.
`home` adds `standalone`. `meta` is passed to modules through `specialArgs` and also
set as options (`config.profile`, `config.host`, `config.role`, ...).

- **`hosts.nix`**: declares `hosts.<name>`; `extends` inherits `system`, `role`, `gpus`
  and `modules` from a parent (parent modules come first so the child can override).
  `role` must be a key of `roles`. Adds `builders.{host,hostModules}`.
- **`home.nix`**: standalone and non-standalone home-manager. Both modes use the same
  module list (`mkModules`), so they evaluate the same config.
  - Standalone gets its base from `cfg.pureBase.builders.mkBase { system = host.system; }`.
  - Non-standalone (`mkHomeNonStandalone`) is called from `nixos.nix` with that config's
    own `base`, `host` and `meta`; it uses `useGlobalPkgs`, so both sides share one pkgs.
  - `root` only gets the `rootHome` modules, never the per-user `home` or desktop modules,
    and only when `withRoot` is true and `username != "root"`.
  - Passes `base.extraSpecialArgs` into home-manager `extraSpecialArgs`.
- **`nixos.nix`**: builds `nixosConfigurations` from `nixos.<name>`, `hosts` and `resolve`.
  Module order: `nixosModules`, host modules, resolved `nixos` modules, `extraModules`,
  then `${paths.modules}/nixos`, role flags, config options, meta, `nixpkgs.pkgs = base.pkgs`.
  When `host.withHome` is true it adds home-manager and `mkHomeNonStandalone`.
  Helpers: `mkNixosModules`, `mkNixosSpecialArgs`, `nixosModulesOf <name>`,
  `nixosSpecialArgsOf <name>` (useful for tests and containers).
- **`nixvim.nix`**: builds a nixvim config per `nixvim.<profile>`. The overlay creates a base
  via `mkBaseFromPkgs { pkgs = final; }` and adds `myPkgs.<profile>` (wrapper with `<profile>`
  and `<profile>-g` for neovide, using `NVIM_APPNAME`). `perSystem` uses the full `base` for
  `nixvimConfigurations`. `startupArgs` is an option of each nixvim config.
- **`package.nix`**: declarative `myPkgs` tree, `ciPackages`, and `flake.mkPkgsFor`.
  Registers its overlay with `nixpkgs.overlays` (applies to every channel).

## Conventions

- Nix style: `nixfmt`-formatted, 2-space indent.
- Comments are written in English and only where they add information. This includes
  option descriptions.
- Error messages start with `registry:`, `hosts:` or the module name, never with `builder:`.
- Prefer `base.builders.<name>` in new code; the flat form exists for convenience.
- Prefer the key name `extraSpecialArgs` (matches home-manager). Do not reintroduce `extraArgs`
  as a base key; `extraArgs` is the argument name of `mkChannel` / `mkPkgs`.
- Names use this vocabulary: `pure` = no pkgs, `mixed` = split automatically,
  `withPkgs` = needs pkgs, `channel` = a nixpkgs instance.
- `roles` is an attrset. To get a list of names use `lib.attrNames cfg.roles` or
  `base.pure.roles`, never `cfg.roles` directly as a list.

## Old names (migration)

| Old                                          | New                                                           |
| -------------------------------------------- | ------------------------------------------------------------- |
| `builder/`                                   | `flake/`                                                      |
| `profiles.nix`                               | `registry.nix`                                                |
| `host.nix`                                   | `hosts.nix`                                                   |
| root `base.nix`                              | `settings.nix` (data only; the mechanism is `flake/base.nix`) |
| `roles` as a list                            | `roles` as an attrset; `lib.attrNames cfg.roles`              |
| `base.attrs`                                 | `base.pure`                                                   |
| `base.attrsProbed`                           | `base.mixed`                                                  |
| `base.attrsPkgsOnly`                         | `base.withPkgs`                                               |
| `builder`                                    | `builders`                                                    |
| `coreBase`, `coreBaseResult`                 | `pureBase`                                                    |
| `base.extraArgs`                             | `base.extraSpecialArgs`                                       |
| `base.forSystem`                             | `builders.baseForSystem` / `builders.mkBase`                  |
| `mkCoreBase`                                 | `mkBaseFromPkgs`                                              |
| `mkStablePkgs`                               | `mkChannel { channel = "stable"; ... }`                       |
| `nixpkgsConfig`, `overlays`, `inputOverlays` | `nixpkgs.config`, `nixpkgs.overlays`, `nixpkgs.inputOverlays` |
| `extraNixpkgsArgs`, `extraNixpkgsStableArgs` | `extraArgs`, `channelArgs.<channel>`                          |
| `extraBase.*`                                | `base.pure.*`                                                 |

## Checks

Shell commands in this repo are written for fish.

```fish
nix flake check --no-build
```

`registryErrors` should be `[ ]`. Changing `roles`, `roleGroups`, `features`, `desktops`,
`tools` or `profiles` is validated there, so run the check after such edits.

Find leftovers of old names:

```fish
rg -n 'builder/|builder:|profiles\.nix|\bhost\.nix|types\.enum cfg\.roles|attrsProbed|attrsPkgsOnly|coreBase|base\.builder\b|cfg\.builder\b|base\.forSystem|base\.extraArgs|extraBase|extraNixpkgs(Stable)?Args|mkCoreBase|mkStablePkgs' .
```

Measure eval cost before and after a change (compare `nrFunctionCalls`, `nrThunks`, `cpuTime`):

```fish
env NIX_SHOW_STATS=1 nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```

## Pitfalls

- `base // { inherit host; }` adds `host` only at the outer layer; `base.base` still
  points to the original base without it. Pass `host` explicitly through `specialArgs`.
- `mkBaseFromPkgs` returns a base with `pkgs` but without `channels`, `myPkgs` or
  `libx` from the full base. Use `final.<channel>` / `final.myPkgs` instead.
- Passing `config` or `overlays` through `extraArgs` merges them with the flake's own
  (lists concatenated, overlays appended); it does not replace them.
- `nixpkgs.<channel>.config` merges on top of root `nixpkgs.config`; functions such as
  `allowUnfreePredicate` cannot be merged and may be defined only once.
- `profilesResult` / `base.pure.profiles` are resolved with `role = null`, so every
  `is<Group>` flag is `false` and `requires` is not enforced. They exist for older callers;
  new code should call `resolve` with `role = host.role`.
- Flags such as `meta.isContainer` exist only if the matching group is in `roleGroups`.
  Removing a group breaks every module that reads its flag.
- `nixvim.<profile>` must have a matching entry in `myPkgs` only if `mkNvimPkg` is used;
  the overlay itself creates `myPkgs.<profile>`, so do not declare the same name in `myPkgs`.
- A file that is not `git add`-ed is invisible to the flake. Stage new or renamed files
  before evaluating.
- Nix does not memoize function calls, only thunks. Bind repeated expressions with
  `let` instead of calling the same function twice.
