# AGENTS.md

## Repository overview
`Pludex/dotfiles` is a flake-based Nix monorepo using `flake-parts` to manage NixOS, Home Manager, and Nixvim. It features a custom builder architecture that separates infrastructure from configuration.

## Core Architecture
- `flake.nix` -> `builder/` -> `outputs.nix` -> Named outputs.
- `builder/base.nix` separates `core` (infrastructure) from `own` (packages/base) to prevent circular dependencies.
- `builder/profiles.nix` handles high-level composition via `profiles.<category>.<subkey>`.
- `outputs.nix` centralizes systems, overlays, and nixpkgs policy.

## Development & Validation
Run these commands from the root:
- `nix develop` — Enter shell with SOPS/Age; exports `GEMINI_API_KEY` and sets `SOPS_AGE_KEY_FILE`.
- `nix fmt` — Format repo using `nixfmt-tree` (configured in `devshells.nix`).
- `nix flake check` — Validate all outputs and modules.
- `nix flake show` — Inspect output schema.

## Conventions
- **Nix**: Use modular `lib.mkIf`/`mkMerge`. Target the narrowest layer (host > profile > module).
- **Secrets**: Encrypted in `data/` via SOPS/Age. Never commit plaintext; use `nix develop` to access.
- **Packages**: Custom tools in `pkgs/` are often wrapped with `writeShellApplication` (see `pkgs/vaultwarden-sync/`).
- **Styles**: Catppuccin/Stylix are used for centralized theming.
- **Electron**: Versions (39, 41) are pinned in `outputs.nix` due to dependencies.

## Pitfalls
- **Circular Dependencies**: Do not access `config.base.pkgs` inside overlay pipelines or `extraBaseWithPkgs`.
- **Permissions**: Hermes dotfiles mounts require `--perms=a+rwX` in bindfs for write access.
- **Secrets**: Editing `.enc.yaml` requires `sops`. Do not bypass the secret extraction logic in `devshells.nix`.
- **Package Manifests**: Some `pkgs/` subdirs (e.g., `patchy-cnb`) use non-Nix manifests (`Cargo.toml`, `package.json`) and require their specific toolchains for builds.
