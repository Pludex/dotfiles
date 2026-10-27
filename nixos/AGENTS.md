# nixos/AGENTS.md

## Overview

System-level modules shared across hosts: services, containers, virtualisation, and a few programs. Host-only hardware and users stay in `hosts/`.

## Layout

- `services/` — host daemons (caddy, nginx, vaultwarden, flatpak, envfs, ngrok).
- `containers/` — declarative containers. `containers/hermes.nix` is a Podman guest built from `base.app "hermes-agent"`, with sops-owned age keys and a subuid range. Do not flatten that into a normal systemd user service.
- `virtualisation/` — libvirt/VM pieces (`win10.nix`, `core/`).
- `programs/hermesctl/` — the host-side CLI that drives the hermes container.
- `apps/` — system apps that are not Home Manager (for example Steam).

## Rules

- Prefer `modules/nixos/` for behavior every host should share (audio, networking, sops, users). Use `nixos/` when the unit is optional and imported by a profile or a host.
- Secrets stay in sops paths. `hermes.nix` restarts `podman-hermes.service` when the age key changes; do not commit decrypted keys or change ownership math without reading that file.
- Container and VM modules evaluate other NixOS configs (`guest.config.system.build.toplevel`). A failure there is often the guest config, not the host module that imports it.
