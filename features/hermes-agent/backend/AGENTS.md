# AGENTS.md

Guidance for AI coding agents working on the `hermes/` home-manager module.

## What this is

A home-manager module that runs NousResearch **hermes-agent** on NixOS (inside the app container user session), wired to **omniroute** (LLM gateway, podman), **oh-my-hermes** (omh), and a desktop theme pack. Secrets come from **sops-nix**.

It exposes one declarative option tree, `services.hermes-agent-backend`, and translates it into:

- the upstream `services.hermes-agent` / `programs.hermes-agent` options (main instance)
- per-profile systemd oneshot services that provision `config.yaml` and `.env`
- omh sync / theme pack services and a refresh timer

## Layout

```
hermes/
  default.nix    # imports only
  options.nix    # option declarations only, no config
  lib.nix        # pure helpers (not a module): env rendering, MCP merging, settings
  main.nix       # main instance, sops secrets, ordering of core units
  profiles.nix   # profile services and per-profile env templates
  omh.nix        # omh sync, theme pack, timer
```

Rules for placement:

- New option → `options.nix`. Never declare options elsewhere.
- Pure logic shared by several files → `lib.nix`. It must not set `config`.
- Behavior of the main instance → `main.nix`; of profiles → `profiles.nix`; of omh or the theme pack → `omh.nix`.
- Every file that sets `config` wraps it in `lib.mkIf cfg.enable`.

## Option model

- `services.hermes-agent-backend.main` and `.profiles.<name>` share the same option set (`instanceOptions`): `model`, `apiKeySecret`, `discord.*`, `mcp`, `excludeMcp`, `env`, `secretEnv`, `settings`.
- Top-level `mcp.<name>` applies to the main instance and every profile. Instance-level `mcp.<name>` overrides it by name (shallow merge). `excludeMcp` removes global servers from one instance.
- MCP servers carry their own `secretEnv` (`ENV_VAR -> sops secret name`). Secrets are exported only to instances that actually use that server.
- `sops.secrets` is generated from every referenced secret name; do not maintain a manual list.
- `omh.chains` is the single source for routing chains; the combo list is derived from it.

## Do not

- Do not use or declare `services.hermes-agent.backend.*` for our own options. Upstream already owns that namespace (`mode`, `sessionTokenFile`). Our namespace is `services.hermes-agent-backend`.
- Do not hardcode secret values or paths to secrets. Reference sops secret names and render through `sops.templates` placeholders.
- Do not write secrets into the Nix store (no `builtins.readFile` of secrets, no secrets in `writeText`/`writeShellScript`).
- Do not add per-profile logic by copying a block. Add or extend an option and iterate over `profiles`.
- Do not hardcode `custom:omniroute` or the omniroute URL in new places; use `cfg.omniroute.baseUrl` and `settingsOf` in `lib.nix`.

## Behavior that is easy to break

- Profile services overwrite `config.yaml`. That drops the omh and theme-switcher plugin enablement, so they delete `.omh-nix-store-path` and the theme/omh units are `PartOf` the profile units. Keep that coupling when changing ordering.
- `.env` files are **merged**, not replaced: `mkMergeEnv` keeps unrelated lines and replaces only the keys present in the sops-rendered template.
- The main instance reads its env via `environmentFiles` (template `hermes-env`). Discord and `OMH_HOME` for main come from that template; only `API_SERVER_*` is set through `services.hermes-agent.environment`.
- `omh-sync` needs `OMNIROUTE_API_KEY` from the `hermes-env` template to query `/v1/models`. If the request fails it keeps the existing `model-providers.json` or falls back to the static routes derived from `omh.chains`.
- Unit ordering lists (`After`/`Wants`/`Before`/`PartOf`) are built from `profileUnits` and `syncUnits` in `lib.nix`. Update those instead of editing lists in several files.
- `omniroute` unit names (`podman-omniroute.service`, `omniroute-bootstrap.service`) are hardcoded in `main.nix` and `omh.nix`.

## Common tasks

Add a profile: add `profiles.<name>` in the host config with `model`, `apiKeySecret`, `discord`, and optionally `mcp` / `excludeMcp`. No module changes needed.

Add a global MCP server: add `mcp.<name>` with `url`, `headers` (reference env vars as `\${NAME}`), and `secretEnv` for any secret it needs.

Add a new kind of per-instance setting: add the option to `instanceOptions` in `options.nix`, consume it in `lib.nix` (`settingsOf`, `plainEnvOf`, or `secretEnvOf`), and verify both main and profile outputs.

Add a new omh routing category: add it to `omh.chains`; nothing else.

## Conventions

- Nix style: `nixfmt` formatting, 2-space indent, `inherit (x) a b;` over repetition.
- Code comments are written in English and only where they explain a non-obvious *why*. Remove comments that restate the code.
- Keep shell scripts under `set -euo pipefail`; pass tools via `lib.makeBinPath`, never rely on ambient `PATH`.
- Prefer `lib.mkIf` / `lib.optionalAttrs` over `if` for module config.

## Verifying changes

There is no test suite; verify by building and inspecting output.

1. Format and evaluate the home-manager configuration that imports this module (use the repo's usual `home-manager build` / flake command).
2. Compare generated artifacts against the previous build: each profile's `config.yaml` and `.env` template, the main `hermes-env` template, and the unit files (`hermes-agent`, `hermes-profile-*`, `omh-sync`, `hermes-theme-pack`).
3. Check that a profile with `excludeMcp` has neither the server in `config.yaml` nor its secret in `.env`.
4. After activation, check `systemctl --user status hermes-profile-<name> omh-sync hermes-theme-pack hermes-agent` and `journalctl --user -u omh-sync` for the "chain model not found" warning.
