# builder/AGENTS.md

## Overview

The `builder/` directory contains the flake-parts builder modules that assemble the entire Nix monorepo (`Pludex/dotfiles`). When editing flake outputs, builder logic, or profile composition, this is the core architecture layer.

## Key Files

1. `builder/default.nix` — Flake-parts entry point; wires all builder modules and `outputs.nix` into `inputs.flake-parts.lib.mkFlake`.
2. `builder/base.nix` — Core composition engine: `mkPkgs`, `mksPkgs`, `mkBase`, `forSystem`, overlay pipeline, and `base` object generation.
3. `builder/home.nix` — Standalone and NixOS-integrated Home Manager configuration generator (`flake.homeConfigurations`).
4. `builder/nixos.nix` — NixOS system configuration generator (`flake.nixosConfigurations`).
5. `builder/profiles.nix` — Profile resolver mapping `profiles.<category>.<subkey>` to concrete module lists via `profilesImportHandlers`.
6. `builder/package.nix` — Hierarchical `myPkgs` package schema, recursive `callPackage`, and `ciPackages` registry.
7. `builder/nixvim.nix` — Nixvim configuration generator (`nixvimConfigurations`) and profile editor wrappers.
8. `builder/host.nix` — Host discovery and resolution helper.

## Architecture Rules & Pitfalls

- **Circular Dependencies**: `builder/base.nix` separates `core` (builders/overlays) from `own` (`pkgs`, `sPkgs`, `myPkgs`) to prevent infinite recursion in nixpkgs evaluation. Never access `config.base.pkgs` inside overlay pipelines or top-level `extraBaseWithPkgs` option declarations.
- **Flake-parts assembly**: Keep composition logic inside `builder/*.nix` modules rather than bloating `outputs.nix`.
- **Validation**: After modifying builder modules, always run `nix flake check` and `nix flake show` to verify derivation evaluation.
