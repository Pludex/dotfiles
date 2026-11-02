# hermes-agent feature

Runs the Hermes desktop/API server and Discord bot inside a rootless Podman container (NixOS guest via `nixosConfigurations.hermes-agent`), managed as a `virtualisation.oci-containers` unit under a dedicated host user (`hermes-host`). The Home Manager backend module provisions config, secrets, OMH, and theme pack for the main instance and per-profile instances (currently `coding` and `study`).

---

## Directory layout

```
features/hermes-agent/
├── default.nix          # Feature entry: module lists, profiles, perSystem packages, extraBase app def
├── container.nix        # NixOS host side: podman container, uid/gid maps, network, sops age key
├── tools.nix            # HM: GitHub App credential helper, extra packages (markitdown, python3, ripgrep)
├── backend/
│   ├── default.nix      # HM top-level: wires options → services.hermes-agent + systemd units
│   ├── options.nix      # NixOS module options for services.hermes-agent-backend
│   ├── lib.nix          # Pure helper: env rendering, sops secret collection, settings/MCP builders
│   ├── main.nix         # HM: main instance + hermes-agent service + env-merge unit
│   ├── profiles.nix     # HM: per-profile sops templates + provision services
│   └── omh.nix          # HM: omh-sync service/timer + hermes-theme-pack service
├── hermesctl/
│   ├── default.hm.nix   # HM: hermesctl shell scripts (mount, exec helpers)
│   ├── default.nixos.nix# NixOS: sudoers rules for hermesctl
│   └── hermes-vars.nix  # Shared variable set used by hermesctl scripts
├── podman/              # Legacy/alternate approach (not active)
└── oh-my-hermes.nix     # myPkgs entry for the OMH package derivation
```

---

## Key identifiers (all sourced from `extraBase.apps.hermes-agent` in `default.nix`)

| Symbol | Value |
|---|---|
| `app.uid` | `2000` |
| `app.username` | `"hermes"` |
| `app.home` | `"/home/hermes"` |
| `app.ports.api` | `8642` |
| `app.ports.dashboard` | `9119` |
| `app.loopback` | `"127.0.0.1"` |
| `app.network.mode` | `"host"` &#124; `"bridge"` (currently `"host"`) |
| `app.network.bindAddress` | `"127.0.0.1"` (host) / `"0.0.0.0"` (bridge) |
| `app.network.hostAddress` | `"127.0.0.1"` (host) / `"host.containers.internal"` (bridge) |
| `hostuser.uid` | `1002` (hermes-host) |
| `hostuser.subUid.start` | `200000` |
| `app.users.container.uid` | `200000 + 2000 - 1 = 201999` (sops secret owner) |
| `app.age.sopsSecret` | `"age-keys/hermes"` |
| `app.container.name` | `"hermes"` |
| `app.container.data` | `"/app/data"` |
| `app.container.workspaces` | `"/workspaces"` |

---

## UID/GID mapping

The container runs as `hermes-host` (uid 1002) with subuid/subgid ranges starting at 200000. The `--uidmap`/`--gidmap` segments defined in `idmap` (sourced from `default.nix`):

**UID map** (container → host intermediate → host uid via subuid table):

| Segment | `inner:outer:count` | Effect |
|---|---|---|
| `root` | `0:0:1` | container root → host root |
| `subordinate` | `1:1:65536` | container 1–65536 → host 200000–265535 |

Container uid 2000 (hermes) maps to host uid **201999** (`200000 + 2000 - 1`). This must match `sops.secrets.${age.sopsSecret}.uid`.

**GID map** (note: first subGid range = coding.gid, second = 200000+):

| Segment | `inner:outer:count` | Effect |
|---|---|---|
| `root` | `0:0:1` | container gid 0 → host gid 0 |
| `belowCoding` | `1:2:coding.gid-1` | intermediate 2..coding.gid |
| `coding` | `coding.gid:1:1` | container coding.gid → intermediate 1 → host coding.gid |
| `aboveCoding` | `coding.gid+1:coding.gid+1:65537-coding.gid` | rest of subordinate range |

The intermediate gid 1 maps to host coding.gid because `subGidRanges` puts `startGid=coding.gid, count=1` **first** (order matters for newgidmap). This allows the container's hermes process (gid = coding.gid) to share files owned by the host `coding` group.

---

## Network modes

Toggle via `app.network.mode` in `default.nix`.

**`"host"` (legacy):** `--network=host`, no port forwarding needed. Guest binds `API_SERVER_HOST=127.0.0.1`. OmniRoute reachable at `127.0.0.1`.

**`"pasta"` (current):** Rootless user-space network stack, no bridge/veth needed. Uses `--network=pasta:--map-host-loopback=<IP>` where `network.pastaHostLoopback = "169.254.1.1"`. Inside the container, connecting to `169.254.1.1:port` reaches host `127.0.0.1:port`. Ports are published as `127.0.0.1:port:port` (same as bridge). Guest binds `0.0.0.0`. OmniRoute baseUrl is `http://169.254.1.1:<omniroute-port>`.

**`"bridge"`:** Named Podman network (`hermes`, `10.89.200.0/24`). Guest binds `0.0.0.0`, ports exposed as `127.0.0.1:8642:8642` and `127.0.0.1:9119:9119`. OmniRoute reachable via `host.containers.internal`. A `podman-network-hermes.service` (oneshot, runs as `hermes-host`) creates the network on boot if absent.

> **Security note:** `--network=host` shares the host network namespace — avoid in production. `pasta` is the recommended rootless mode: it isolates the network namespace while still reaching host loopback services via the mapped IP. `pastaHostLoopback` must be an IP not in use on the host; `169.254.1.1` (link-local) is a safe default.

---

## Secrets and environment

All secrets are managed by `sops-nix`. The module collects required sops secrets automatically via `lib.nix:allSecrets` (union of `sessionTokenSecret`, all `apiKeySecret`, `discord.tokenSecret`, `allowedUsersSecret`, plus any `secretEnv` from MCP servers and instances).

Sops templates render as env files, merged into `HERMES_HOME/.env` by `hermes-env-merge.service` (oneshot, before hermes-agent starts).

Per-profile env files (`hermes-env-coding`, `hermes-env-study`) are written by `hermes-profile-{name}.service`.

> **Never** add plain secrets to `services.hermes-agent.environment` — use `secretEnv` in the instance/MCP options instead.

---

## MCP server inheritance

Global servers (`services.hermes-agent-backend.mcp`) are applied to every instance. Per-instance `mcp` overrides by name. Use `excludeMcp` to drop a global server from a profile (e.g. `study` excludes `omniroute` and `github`).

---

## Adding a profile

1. Add an entry under `services.hermes-agent-backend.profiles` in `backend/default.nix`.
2. Supply `model`, `apiKeySecret`, `discord.*`.
3. Add the corresponding sops secrets (the module collects them automatically).
4. No other files need editing — `profiles.nix` generates the service and sops template dynamically.

---

## Switching network mode

Change `network.mode` in `extraBase.apps.hermes-agent` (`default.nix`). On first switch to bridge:
- The `podman-network-hermes.service` will create the network.
- `container.nix` will add port publish entries and remove `--network=host`.
- `backend/default.nix` will set `API_SERVER_HOST=0.0.0.0` and route OmniRoute via `host.containers.internal`.

No other files need changing — all conditionals key off `isBridge`.

---

## Common pitfalls

- **`app.port` vs `app.ports.api`** — The app attrset no longer has a flat `.port`; use `.ports.api` (8642) or `.ports.dashboard` (9119). `backend/options.nix` defaults to `.ports.api`.
- **`$OMNIROUTE_API_KEY` in omh-sync** — The curl call in `omh.nix` uses `$OMNIROUTE_API_KEY` (injected via `EnvironmentFile`). If you see auth failures in `omh-sync`, verify the `hermes-env` sops template is rendered and the service `After=hermes-env-merge.service`.
- **subGidRanges order** — The `coding.gid` range must be **first** in `subGidRanges` so it becomes intermediate gid 1. Reordering breaks the gidmap.
- **sops secret uid** — `sops.secrets.${age.sopsSecret}.uid` must equal `app.users.container.uid` (201999). If the container can't read its age key, check this value matches.
- **`nix-daemon.sock` mount** — The volume `/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket` is present for the guest NixOS init; it is **not** exposed to the hermes process (which runs as uid 2000). Do not remove it — the guest systemd needs it — but do not grant hermes user access to the socket group.
- **`hermes-env-merge` vs `environmentFiles`** — `hermes-agent.service` already gets `EnvironmentFile` from the sops template directly. `hermes-env-merge` writes a persistent `.env` file for tools that read it from disk (hermesctl scripts, profile discovery). Both are needed.
