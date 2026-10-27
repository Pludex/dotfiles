# home/AGENTS.md

## Overview

Home Manager modules for the user environment: apps, CLI programs, IDEs, AI tools, flatpak, and user services. These are imported through profiles and the desktop `home` side, not by adding files at the flake root.

## Layout

- `ai/` — AI clients, services, tools, and modules. `ai/default.nix` imports `./services` and `./clients`.
- `apps/` — GUI apps (one module per app).
- `develop/` — language/toolchains that belong to the user, not the OS (`dotnet.nix`, `android.nix`).
- `programs/` — CLI and shells. Nested dirs (`nushell`, `zsh`, `wezterm`, …) are multi-file programs; flat `*.nix` files are single modules.
- `ides/`, `flatpak/`, `services/` — IDEs, Flatpak, and user daemons (for example `services/hermes-agent.nix`, `services/audio-manager/`).

## Module contract

Modules under `modules/home/` (imported for every home config) receive `base`, and optionally `osConfig` and `meta`. `osConfig == null` means a standalone `homeConfigurations` build, not a NixOS-attached one. Container homes force `home.username` / `home.homeDirectory` from `base.app`; do not hardcode those paths here.

## Rules

- New user-facing behavior goes in the narrowest existing directory. Reusable options go in `modules/home/`, not a one-off under `home/programs/`.
- Do not put host hardware, networking, or system services in this tree; those belong in `nixos/` or `hosts/`.
- Profile wiring is `profiles/*.nix` plus `builder/profiles.nix`. A file that exists here is not active until a profile imports it.
