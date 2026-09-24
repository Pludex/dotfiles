# AGENTS.md

## Repository overview

`Pludex/dotfiles` is a flake-based Nix monorepo for a personal NixOS workstation and Home Manager environment. It declaratively manages operating-system configuration, user applications and services, desktop environments, and project-local tooling via a single flake interface.

The primary implementation language is **Nix**. The repository also contains Python, Rust, Nushell, Bash, Emacs Lisp, YAML, JSON, and CSS/configuration files where appropriate.

## Start here

Read these files in this order before making a non-trivial change:

1. `flake.nix` — flake inputs, cachix configuration, and the top-level output entry point.
2. `builder/default.nix` — the root of the flake-parts assembly; it imports every builder module and wires the flake together.
3. `builder/base.nix` — the core composition engine: `mkPkgs`, `mksPkgs`, `mkBase`, `forSystem`, overlays, `extraBase`, and the per-system `base` object.
4. `builder/home.nix` — Home Manager and standalone configuration generation, including module composition and `extraSpecialArgs` propagation.
5. `builder/nixos.nix` — NixOS system generation, host/desktop/profile resolution, and embedded Home Manager integration.
6. `builder/profiles.nix` — the profile resolver that flattens `profiles.<category>.<subkey>` into concrete module lists via `profilesImportHandlers`.
7. `builder/package.nix` — the `myPkgs` package schema, overlay-based package generation, and `ciPackages` registry.
8. `builder/nixvim.nix` — nixvim configuration generation, overlay-based `myPkgs.<profile>` packaging, and `nixvimConfigurations` output shape.
9. `outputs.nix` — named Home Manager, NixOS, and Nixvim outputs, supported systems, overlays, and formatting.
10. The target host/profile/module — choose the narrowest relevant configuration instead of changing a global layer.

The current supported system is `x86_64-linux`. Named outputs and their composition are defined in `outputs.nix`; do not infer a new host, profile, or desktop name without checking that file first.

## Flake-parts builder architecture

This repository is organized around a flake-parts builder, not a single giant `outputs.nix` file. The key architectural pattern is:

- `flake.nix` declares the flake inputs and then calls `((import ./builder { inherit inputs; }).mkDotfiles {})`.
- `builder/default.nix` is the flake-parts entry point. It imports the builder modules and then attaches them to an `inputs.flake-parts.lib.mkFlake` configuration.
- The modules in `builder/*.nix` each contribute a small, explicit slice of the flake: base system setup, Home Manager generation, NixOS generation, profile resolution, packages, and nixvim outputs.
- `outputs.nix` is not the entire architecture; it supplies the high-level named outputs and global settings while the builder modules handle the actual composition logic.

The most important builder modules are:

- `builder/base.nix`
  - Defines the repo's shared flake-level infrastructure.
  - Creates `mkPkgs`, `mksPkgs`, `mkBase`, and `forSystem` helpers.
  - Builds a per-system `base` object with `pkgs`, `sPkgs`, `myPkgs`, `libx`, and `builder` helpers.
  - Maintains the overlay pipeline and `extraBase`/`extraBaseWithPkgs` hooks.
  - This is the abstraction that keeps overlay ordering, package channels, and system-specific assembly consistent.

- `builder/home.nix`
  - Produces `flake.homeConfigurations` for standalone home-manager builds.
  - Shares one module list for both standalone and non-standalone modes.
  - Injects `profile`, `desktop`, `name`, and `standalone` into modules via `extraSpecialArgs` and module arguments.
  - Allows NixOS configurations to attach Home Manager with `base.mkHomeNonStandalone`.

- `builder/nixos.nix`
  - Produces `flake.nixosConfigurations` from the `nixos` attrset.
  - Resolves host, profile, desktop, and system together.
  - Imports the host module, desktop module, shared nixos module path, and Home Manager NixOS module.
  - Wires the NixOS config into the repo's Home Manager config via `home-manager = base.mkHomeNonStandalone { inherit config base; };`.

- `builder/profiles.nix`
  - Defines the `profiles` option and `profilesImportHandlers` mechanism.
  - Allows declarative entries like `profiles.desktop.home = { foo = [ "bar" ]; };` to resolve to actual module paths.
  - Flattens each category/subkey into a list of imported modules, exposed as `profilesResult`.
  - This is the mechanism that makes `profile`-based composition work without hard-coding every combination.

- `builder/package.nix`
  - Defines the hierarchical `myPkgs` package schema.
  - Builds package derivations via recursive `callPackage` evaluation.
  - Exposes `packages`, `legacyPackages`, and `ciPackages` as flake outputs.
  - Keeps CI package selection explicit and easy to inspect via `ciBuild`.

- `builder/nixvim.nix`
  - Generates `nixvimConfigurations.<system>.<profile>` using `inputs.nixvim.lib.evalNixvim`.
  - Adds profile-specific modules through `cfg.nixvimModules` and `profilesResult.<profile>.nixvim`.
  - Bakes profile wrappers into `pkgs.myPkgs.<profile>` so each profile gets a convenience `nvim` / `profileide` package.

- `outputs.nix`
  - Declares the repo's named outputs: `home`, `nixos`, and `nixvim`.
  - Selects supported systems and keeps overlays and nixpkgs policy centralized.
  - Imports the repo's `base`, `pkgs`, and `profiles` directories so the builder modules can compose all of them.

In other words, the flake-parts builder is the architecture: base infrastructure first, then specialized generators for OS/user/editor/profile/package outputs, with `profiles` and `myPkgs` as the central composition mechanisms.

## Directory map

```text
.
├── flake.nix / flake.lock     # Flake inputs, lockfile, and top-level entry point
├── outputs.nix                # Named outputs, systems, overlays, nixpkgs policy, treefmt
├── default.nix                # Compatibility entry point using flake-compat
├── devshell.nix               # Development shell with SOPS/Age tooling
├── base/                      # Shared options, paths, tools, glyphs, and base configuration
├── builder/                   # Flake Parts assembly for base, NixOS, Home Manager, Nixvim, packages, profiles
├── profiles/                  # High-level compositions such as desktop, live, and development profiles
├── hosts/                     # Host-specific NixOS configuration
├── nixos/                     # System services and virtualization configuration
├── home/                      # Home Manager modules: apps, programs, services, development, IDEs, and AI tools
├── desktops/                  # Desktop/window-manager compositions and desktop-specific Home Manager setup
│   ├── common/                # Shared desktop utilities
│   ├── niri/                  # Niri configuration
│   └── MangoWM/               # MangoWM configuration
├── modules/                   # Reusable modules
│   ├── flake/                 # Flake-level modules
│   ├── home/                  # Reusable Home Manager modules
│   ├── nixos/                 # Reusable NixOS modules
│   └── nixvim/                # Reusable Nixvim modules
├── nixvim/                    # Nixvim language and editor-specific configuration
├── emacs/                     # Emacs configuration and package setup
├── overlays/                  # Nixpkgs overlays
├── pkgs/                      # Custom packages and project-local tools
├── data/                      # Encrypted secrets and static data; handle as sensitive
├── lib/                       # Local Nix library functions and helpers
├── .github/                   # GitHub configuration and automation
├── .sops.yaml                 # SOPS/Age encryption rules
└── .envrc                     # direnv integration
```

### Custom package areas

The `pkgs/` tree includes project-local tools implemented in multiple languages, notably:

- `audio-manager/` — Python MPRIS/audio-management daemon.
- `vaultwarden-sync/` — Python backup and synchronization utility.
- `vivaldi-sync/` — Nushell browser-profile synchronization utility.
- `patchy-cnb/` — Rust/NAPI-RS package for input, window, and monitor operations.

When changing one of these packages, follow the package's own manifest and existing implementation style before introducing a new build mechanism.

## Core technologies and architecture

- **Nix flakes** with `nixpkgs` unstable as the primary package set and a stable `nixpkgs` input where needed.
- **flake-parts** to compose the flake from focused modules in `builder/`.
- **NixOS** for system-level configuration under `hosts/`, `nixos/`, `profiles/`, and `modules/nixos/`.
- **Home Manager** for user-level configuration under `home/`, `desktops/`, `profiles/`, and `modules/home/`.
- **Nixvim** for declarative Neovim configuration under `nixvim/` and `modules/nixvim/`.
- **Stylix/Catppuccin** and desktop-specific modules for centralized theming.
- **Wayland desktop stack**, including Niri, MangoWM, Waybar, and related utilities.
- **SOPS + Age** for encrypted secrets. Secrets are referenced through configuration paths and must never be replaced with plaintext credentials.
- **treefmt** for formatting Nix, Prettier-supported files, and shell files. The repository enables `nixfmt` and `shfmt`; Ruff is currently not enabled in the shared treefmt configuration.
- **Custom overlays and flake inputs** for packages, editor integrations, fonts, Firefox extensions, virtualization, and desktop components.

The main output flow is:

```text
flake.nix
  -> builder/default.nix
    -> builder/{base,nixos,home,nixvim,package,profiles}.nix
      -> outputs.nix + base/ + profiles/ + pkgs/
        -> named home/nixos/nixvim outputs
```

## Development and validation

Use the repository's flake environment when possible:

```bash
# Enter the development shell; this also exposes SOPS/Age tooling.
nix develop

# Inspect available outputs.
nix flake show

# Evaluate/check the flake.
nix flake check

# Format the repository using the configured formatter.
nix fmt

# Format-check without changing files, when supported by the local Nix version.
nix fmt -- --check
```

Before submitting a change:

1. Run `nix fmt` or format only the files you changed with the configured tools.
2. Run `nix flake check`.
3. If the change affects a specific host, profile, desktop, package, or module, evaluate/build that target as well when practical.
4. Review `git diff` and confirm that `flake.lock` changed only when dependency updates were intentional.
5. Never commit decrypted secret material, Age private keys, API keys, or generated credentials.

If evaluation requires unavailable hardware, private secrets, or a local-only path, report that limitation instead of weakening the configuration to make the check pass.

## Rules for AI agents

### Scope and investigation

- Inspect the relevant imports and option definitions before editing. Nix modules are connected through imports and option declarations; a local-looking change may have global effects.
- Prefer the narrowest layer that solves the problem: host-specific settings belong in `hosts/`, reusable system behavior in `modules/nixos/`, user behavior in `home/` or `modules/home/`, and desktop- or profile-level behavior in `desktops/` or `profiles/`.
- Reuse existing options, helpers, overlays, and package definitions. Do not create a duplicate abstraction without checking for an existing one first.
- Preserve the existing naming and directory conventions. Keep related configuration together rather than adding unrelated top-level files.
- Do not make drive-by refactors, dependency upgrades, formatting churn, or lockfile updates unrelated to the requested task.
- When working in the flake-parts builder, treat `builder/default.nix` and its imported modules as the source of architectural truth. Follow the pattern established there rather than introducing alternate composition styles.

### Nix style and correctness

- Write idiomatic, modular Nix. Prefer existing module options and `lib.mkIf`, `lib.mkMerge`, `lib.mkDefault`, and `lib.mkOption` patterns where appropriate.
- Preserve the distinction between NixOS modules, Home Manager modules, flake modules, packages, and plain configuration values.
- Keep `inputs.*.follows` relationships intact unless intentionally changing dependency resolution.
- Treat `flake.lock` as generated state: update it only for an intentional input change and include the reason in the change summary.
- Keep `allowUnfree`, insecure-package exceptions, overlays, and cache settings centralized in their existing locations; do not scatter policy overrides through leaf modules.
- Avoid absolute paths and machine-specific assumptions unless the existing architecture explicitly provides them through `base.paths` or host configuration.
- For builder changes, preserve the design of `base`, `profiles`, `myPkgs`, and `home/nixos/nixvim` configuration generation; the repository relies on those module contracts.

### Secrets and safety

- Never print, decrypt into the repository, or commit secret contents.
- Do not change `.sops.yaml`, encrypted files, Age key paths, or secret extraction logic unless the task explicitly concerns secret management.
- Use placeholders in examples and tests. Do not ask a user to paste private keys or API tokens into chat.
- Treat `data/` as sensitive even when a file appears to be configuration data.

### Other languages

- Python: follow the local style, use type hints where the surrounding code does, and preserve established synchronous/asynchronous behavior.
- Rust/NAPI-RS: keep Rust code safe and idiomatic and maintain compatibility with the package manifest and generated TypeScript declarations.
- Nushell/Bash: preserve existing shell semantics, quote paths, and use explicit failure handling; do not silently ignore command failures.
- Emacs Lisp and editor configuration: follow the existing module/file organization instead of embedding large unrelated configuration blocks.

### Change communication

Every implementation summary should state:

- which files and configuration layer changed;
- which output/host/profile is affected;
- what validation was run and its result;
- any checks not run and why.

If the requested behavior conflicts with the current architecture or cannot be validated safely, explain the conflict and propose the smallest safe alternative before making broad changes.
