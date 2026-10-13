<!--
SPDX-License-Identifier: MIT

Copyright (c) Nous Research and hermes-agent contributors
  Original work: nix/moduleCommon.nix and nix/homeManagerModules.nix
  https://github.com/NousResearch/hermes-agent

Copyright (c) 2026 <YOUR NAME>
  Modifications and this document: single-module podman variant for
  Home Manager (`hermes-podman`).

NOTE: confirm the licence against the LICENSE file of the upstream repository
and keep this header in sync with it.
-->

# AGENTS.md — hermes-podman

Instructions for AI coding agents (and humans) working on this repository.

## What this is

`hermes-podman.nix` is a **single Home Manager module** that runs Hermes Agent
in **rootless Podman containers** (systemd user units, via Home Manager's
`services.podman.containers`). It is a personalised derivative of two upstream
files from NousResearch/hermes-agent: `nix/moduleCommon.nix` and
`nix/homeManagerModules.nix`.

- Linux only. Darwin is a future target and will use the upstream module
  natively, which is why our options live under a different root.
- The runtime is the container image. The Nix `package` is used only at build
  time to read `_config_version` (or skipped when `configVersion` is set).

## Naming rules (do not break)

- Option roots are `services.hermes-podman` and `programs.hermes-podman`.
  **Never** declare or set `services.hermes-agent.*` or
  `programs.hermes-agent.*` here. Those belong to upstream and must be able to
  coexist with this module.
- Default container name is `hermes-podman` (backend: `hermes-podman-backend`).
  Default CLI wrapper is `hermes`, configurable by
  `programs.hermes-podman.commandName`.
- User-facing strings and error messages say `hermes-podman`, not
  `hermes-agent`.

## Layout

| Path                 | Purpose                                   |
| -------------------- | ----------------------------------------- |
| `hermes-podman.nix`  | The whole module: options and config      |
| `AGENTS.md`          | This file                                 |

External dependencies (not in this repo):

- Home Manager (`lib.hm.dag`, `config.home.homeDirectory`,
  `services.podman`).
- Optional flake `inputs` in `extraSpecialArgs`, only for the default
  `package` (`inputs.self.packages.<system>.default`, with `.hermesVenv`).
- The container image `docker.io/nousresearch/hermes-agent` (entrypoint is
  `hermes`).

## Conventions

- Format with `nixfmt` (RFC style). Keep `lib` references explicit (`lib.mkIf`
  or `inherit`), no `with lib;`.
- Options: every option has `type`, `default`, `description`. Add `example` or
  `literalExpression` when the shape is not obvious.
- Inside `''` strings, escape Nix interpolation meant for the shell as
  `''${...}`. Quote shell paths with `lib.escapeShellArg(s)`.
- Activation runs inside `podman unshare`. Do not call `chown`; ownership is
  handled by the `:U` volume flag and the user namespace.
- Keep unsupported upstream options **removed**, not stubbed: `user`, `group`,
  `stateDir`, container-mode of NixOS, `installPackage`,
  `extraPythonPackages`, `extraDependencyGroups`, `extraPackages`,
  `backend.waitFor`, `backend.interfaceName`, `backend.waitTimeout`,
  `backend.sessionTokenFile`. They have no effect in a container.

## Security rules

- Never put secrets in the Nix store. Secret-bearing options use `types.str`
  runtime paths (`environmentFiles`, `authFile`). Never change them to
  `types.path`.
- `environment` is for non-secret values only.
- `.env`, `auth.json`, `config.yaml`, documents are mode `0600`.
- Non-loopback `backend.host` enables the dashboard auth gate. Put
  `HERMES_DASHBOARD_SESSION_TOKEN=<token>` in `environmentFiles`.
- Document keys must be relative paths without `..` (enforced by assertion).

## Behaviour to preserve

- `settings` is deep-merged (`lib.recursiveUpdate`) across modules, and deep
  merged again into the `config.yaml` on disk. Nix keys win; runtime keys stay.
- `terminal.cwd` is the path **inside the container**.
- Both containers share `hermesHome`, mounted at `/opt/data`.
- `config.yaml` is written atomically.

## Verify before finishing

```sh
nixfmt hermes-podman.nix
nix-instantiate --parse hermes-podman.nix >/dev/null      # syntax
home-manager build --flake .#<user>                       # evaluation + build
systemctl --user list-units 'podman-hermes-podman*'       # after switch
```

If you change an option, check that no reference to the old name remains
(`grep -n 'hermes-agent' hermes-podman.nix` should only show the image name,
the licence header and upstream URLs).

## Syncing with upstream

1. Diff upstream `nix/moduleCommon.nix` and `nix/homeManagerModules.nix`
   against the previous sync.
2. Port only what applies to the podman variant. Rename every
   `hermes-agent` option path to `hermes-podman`.
3. Keep the copyright header, and add yourself under "Modifications".

## Copyright rule

Every source file carries the header from the top of this file (adapted to the
comment syntax). Do not remove the upstream notice. Add new modifications under
the second copyright line.
