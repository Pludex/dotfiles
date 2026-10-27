# modules/AGENTS.md

## Overview

Reusable modules, split by evaluation context. Importing the wrong tree is a type error or a silent no-op, not a style nit.

## Layout

- `modules/nixos/` — NixOS modules (audio, bluetooth, networking, users, sops, keyboard, xdg).
- `modules/home/` — Home Manager modules imported for both standalone and NixOS-attached homes. `default.nix` sets `home.stateVersion`, session variables from `base.tools.envvars`, and container vs host username/home.
- `modules/nixvim/` — nixvim modules (`core`, `edit`, `file`, `git`, `languages`, `terminal`, `ui`, `utils`).
- `modules/flake/` — flake-parts modules (for example `nixvimConfigurations.nix`), not a NixOS or HM module.

## Arguments you can rely on

- NixOS and HM modules in this repo are passed `base` (paths, tools, apps, libx). Do not reimplement `base.paths` with absolute paths.
- HM modules may see `osConfig` (`null` when standalone) and `meta`.
- Nixvim modules are a third module system. Do not import a `modules/nixos/*` file from nixvim or the reverse.

## Rules

- New shared options go here. Leaf files under `home/`, `nixos/`, or `desktops/` should set those options, not redeclare them.
- `isContainer` on the home side is derived from `osConfig` when present. Do not `mkForce` it from an app module.
