# desktops/AGENTS.md

## Overview

Desktop compositions for NixOS + Home Manager. Each desktop name is a directory under `desktops/` and must expose both a NixOS side and a Home Manager side.

## Resolution

`desktops/default.nix` is `{ desktop }: { nixos, home }`. For a name it looks up `./${desktop}/nixos.nix` or `./${desktop}/nixos`, then the same for `home`. Missing either throws. Do not invent a desktop name that is not a directory here and also named in `outputs.nix`.

## Layout

- `common/` — shared HM pieces (waybar, swaync, fuzzel, hyprlock, walker, wlogout, clipse). Import these from a desktop's `home` instead of copying them.
- Per desktop (`niri`, `mango`, `river`, `hyprland`, `plasma6`, `tty`): `nixos.nix` plus `home.nix` or a `home/` directory of modules.
- `river/AGENTS.md` is desktop-local and wins over this file for work under `desktops/river/`.

## Rules

- Wayland stack and theming stay in the desktop or in `modules/home/style.nix`. Do not put compositor config in `hosts/` or `nixos/services/`.
- A desktop change affects every host that selects that desktop. Check `outputs.nix` before assuming only one host is hit.
- After a layout change, evaluate the host that uses it (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or the matching home config) rather than only `nix flake check`.
