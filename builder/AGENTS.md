# AGENTS.md

Guide for agents working on the flake-parts "base" layer and the modules built on it
(`base.nix`, `home.nix`, `nixvim.nix`, `package.nix`, `profiles.nix`).

## Overview

`base.nix` builds a shared attribute set called `base` that every other module consumes.
It exists in two forms:

- **`pureBase`**: never depends on `pkgs`. Available at the flake level as
  `config.pureBase` and as `_module.args.base` at the top level.
- **Full base**: `pureBase` plus everything that needs a real `pkgs`. Built per system
  and available as `perSystem.base` / `_module.args.base` inside `perSystem`.

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

Channels are defined by `channelSrcs` in `base.nix`; `unstable` is `mainChannel` and
backs `pkgs`. **Adding a channel is one line in `channelSrcs`**. The options,
`pkgs.<name>`, `base.channels.<name>` and `base.<name>Pkgs` are generated from it.

## Base contents

**`pureBase`**: `inputs`, `sources` (same as `inputs`), `paths`, `libx`, all `builders`
(flat), `base.pure`, pkgs-free part of `base.mixed`, `builders` (namespaced),
`extraSpecialArgs` (pkgs-free part), `base` (itself).

**Full base** adds, later wins: pkgs-dependent part of `base.mixed`, `base.withPkgs`,
`extraAttrs`, then fixed keys: `pkgs`, `channels`, `<channel>Pkgs`, `myPkgs`, `libx`,
`extraSpecialArgs` (resolved with real pkgs), `base`.

**Builders** (always available at `base.builders.*` and flat): `mkBase`,
`mkBaseFromPkgs`, `mkPkgs`, `mkChannel`, `baseForSystem`, `pkgsForSystem`,
`channelForSystem`, plus anything the user defines in `builders`.

**Inside `pkgs`**: `pkgs.<channel>`, `pkgs.base` (= `pureBase`), `pkgs.inputs`,
`pkgs.sources`, `pkgs.libx`, and everything from `inputPackages`.

## Consumers

- **`home.nix`**: standalone and non-standalone home-manager. Gets its base from
  `cfg.pureBase.builders.mkBase { system = host.system; }`. Passes
  `base.extraSpecialArgs` into home-manager `extraSpecialArgs`.
- **`nixvim.nix`**: builds nixvim configs per profile. The overlay creates a base via
  `mkBaseFromPkgs { pkgs = final; }`; `perSystem` uses the full `base`.
- **`package.nix`**: declarative `myPkgs` tree, `ciPackages`, and `flake.mkPkgsFor`.
  Registers its overlay with `nixpkgs.overlays` (applies to every channel).
- **`profiles.nix`**: resolves profiles into module lists and publishes them as
  `base.pure.profiles`.

## Conventions

- Nix style: `nixfmt`-formatted, 2-space indent.
- Comments are written in English and only where they add information. This includes
  option descriptions.
- Prefer `base.builders.<name>` in new code; the flat form exists for convenience.
- Prefer the key name `extraSpecialArgs` (matches home-manager). Do not reintroduce `extraArgs`
  as a base key; `extraArgs` is the argument name of `mkChannel` / `mkPkgs`.
- Names use this vocabulary: `pure` = no pkgs, `mixed` = split automatically,
  `withPkgs` = needs pkgs, `channel` = a nixpkgs instance.

## Old names (migration)

| Old                                          | New                                                           |
| -------------------------------------------- | ------------------------------------------------------------- |
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

Find leftovers of old names:

```fish
rg -n 'attrsProbed|attrsPkgsOnly|coreBase|base\.builder\b|cfg\.builder\b|base\.forSystem|base\.extraArgs|extraBase|extraNixpkgs(Stable)?Args|mkCoreBase|mkStablePkgs' .
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
- Nix does not memoize function calls, only thunks. Bind repeated expressions with
  `let` instead of calling the same function twice.
