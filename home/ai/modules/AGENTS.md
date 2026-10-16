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
- The runtime is the container image. The Nix `package`
  (default `pkgs.hermes.full`) is used only at build time to read
  `_config_version`. It is not evaluated when `configVersion` is set.
- Linger must be enabled (`loginctl enable-linger <name>`), or the user
  manager and the containers stop at logout.

## Naming rules (do not break)

- Option roots are `services.hermes-podman` and `programs.hermes-podman`.
  **Never** declare or set `services.hermes-agent.*` or
  `programs.hermes-agent.*` here. Those belong to upstream and must be able to
  coexist with this module.
- Containers are `<podman.namePrefix>-gateway` and `<podman.namePrefix>-backend`.
  The default prefix is `hermes`, so the defaults are `hermes-gateway` and
  `hermes-backend`, and the units are `podman-hermes-gateway.service` and
  `podman-hermes-backend.service`.
- CLI wrappers: `<commandName>` (default `hermes`), `<commandName>-tui`,
  `<commandName>-web`. Configurable by `programs.hermes-podman.commandName`.
- User-facing strings and error messages say `hermes-podman`, not
  `hermes-agent`.

## Layout

| Path                | Purpose                              |
| ------------------- | ------------------------------------ |
| `hermes-podman.nix` | The whole module: options and config |
| `AGENTS.md`         | This file                            |

External dependencies (not in this repo):

- Home Manager (`lib.hm.dag`, `config.home.homeDirectory`,
  `services.podman`).
- `pkgs.hermes.full` and `pkgs.hermes.desktop` from an overlay, used only for
  the default `package` and `desktop.package`.
- The container image `docker.io/nousresearch/hermes-agent` (entrypoint is
  `hermes`).

## How it works

1. **State setup** (`stateScript`, serialised with `flock` because the gateway
   and backend units run it in parallel). It runs twice: as the Home Manager
   activation entry `hermesPodmanSetup`, and as `ExecStartPre` of each
   container unit. It does the following:
   - creates `hermesHome`, `workingDirectory` and the subdirs in `stateSubdirs`
   - deep-merges the Nix `settings` into `config.yaml` (`mergeScript`), or
     installs `configFile` unchanged
   - writes `.managed`
   - **rewrites `.env` from scratch**: `environment` first, then each file of
     `environmentFiles` appended (unreadable files only produce a warning)
   - copies `authFile` to `auth.json` (only if missing, unless
     `authFileForceOverwrite`)
   - installs `documents` into `workingDirectory` and `hermesHomeFiles` into
     `hermesHome`
   - recreates the `nix-managed-*` plugin symlinks from `extraPlugins`
2. **Containers** (`mkContainer`): host network, `hermesHome` mounted at
   `/opt/data`, `HERMES_HOME` and `HERMES_MANAGED=home-manager` set,
   `environmentFiles` passed with `--env-file`.
3. **Host wrappers** (`mkCli`): `podman exec` into the running gateway (or
   backend) container, with a one-shot `podman run` fallback that uses the same
   mounts and environment. The desktop app is wrapped to use the backend URL (default port **9119**).

## Permission modes

- `keep-id` (default): the container runs with
  `--userns=keep-id:uid=<uid>,gid=<gid>` (default 10000), so `hermesHome`
  stays owned by the host user. The state script runs directly, with no
  `podman unshare`.
- `chown`: volumes get `:U` and the state script runs inside
  `podman unshare`. Files end up owned by a subuid, so the host user cannot
  edit them. Do not call `chown` manually in either mode.
- `programs.hermes-podman.desktop` requires `keep-id` (asserted).

## Conventions

- Format with `nixfmt` (RFC style). Keep `lib` references explicit (`lib.mkIf`
  or `inherit`), no `with lib;`.
- Options: every option has `type`, `default`, `description`. Add `example` or
  `literalExpression` when the shape is not obvious.
- Inside `''` strings, escape Nix interpolation meant for the shell as
  `''${...}`. Quote shell paths with `lib.escapeShellArg(s)`.
- Keep unsupported upstream options **removed**, not stubbed: `user`, `group`,
  `stateDir`, container-mode of NixOS, `installPackage`,
  `extraPythonPackages`, `extraDependencyGroups`, `extraPackages`,
  `backend.waitFor`, `backend.interfaceName`, `backend.waitTimeout`,
  `backend.sessionTokenFile`. They have no effect in a container.
- Add an assertion for every invalid option combination, and a warning for
  harmless misconfiguration.

## Security rules

- Never put secrets in the Nix store. Secret-bearing options use `types.str`
  runtime paths (`environmentFiles`, `authFile`, `desktop.remoteTokenFile`).
  Never change them to `types.path`.
- `environment` is for non-secret values only. It is written to `.env` and
  passed to the containers.
- `.env`, `auth.json`, `config.yaml`, documents are mode `0600`.
- Non-loopback `backend.host` enables the dashboard auth gate. Put
  `HERMES_DASHBOARD_SESSION_TOKEN=*** in `environmentFiles`.
- Document keys must be relative paths without `..` (enforced by assertion).

## Behaviour to preserve

- `settings` is deep-merged (`lib.recursiveUpdate`) across modules, and deep
  merged again into the `config.yaml` on disk. Nix keys win; runtime keys stay.
- `mcpServers` is converted by `mcpServersToConfig` and merged into
  `settings.mcp_servers`. Stdio servers run inside the container.
- `terminal.cwd` is the path **inside the container**
  (`containerWorkdir`). A `workingDirectory` outside `hermesHome` gets its own
  volume at the same path.
- Both containers share `hermesHome`.
- `config.yaml` is written atomically (tmp file, then rename).
- `.env` is rebuilt on every activation and every container start, so runtime
  edits to it are lost by design.
- `extraPlugins` mounts `/nix/store` read-only into the containers.

## Gotchas

- Removing a key from `settings` does **not** remove it from `config.yaml` on
  disk, because the merge keeps keys that Nix does not set. Edit the file or
  delete it (it is regenerated) to drop stale values.
- `configFile` replaces `settings` and overwrites runtime edits on each
  activation.
- A secret in `environmentFiles` must be rendered before the state script
  runs, so order the units after `sops-nix.service` with `podman.after` and
  `podman.wants`. Otherwise `.env` silently lacks the keys (only a warning is
  logged).
- Container name in `podman exec` and `journalctl` is
  `<namePrefix>-gateway`, not `hermes`.

## Verify before finishing

```sh
nixfmt hermes-podman.nix
nix-instantiate --parse hermes-podman.nix >/dev/null      # syntax
home-manager build --flake .#<user>                       # evaluation + build
systemctl --user list-units 'podman-hermes*'              # after switch
podman ps -a --format '{{.Names}}\t{{.Status}}'

