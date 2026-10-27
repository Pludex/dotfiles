# nixvim/AGENTS.md

## Overview

Profile-facing nixvim configuration. `nixvim/default.nix` imports `modules/nixvim/*` plus a few local extras (`direnv.nix`, `leetcode.nix`, `obsidian.nix`, `neovide.nix`, `img.nix`, `window.nix`). Language servers and treesitter live in `nixvim/languages/*.nix`.

## How it becomes a package

`builder/nixvim.nix` evaluates a profile with `inputs.nixvim.lib.evalNixvim` and adds `profilesResult.<profile>.nixvim`. The wrapper the user actually runs is `pkgs.myPkgs.<profile>` (`nvim` / `profileide`), not a raw `nixvim` binary from nixpkgs. Changing only a language module does nothing until that profile lists it.

## Rules

- Add a language under `nixvim/languages/` and import it from the languages aggregate. Do not paste LSP config into `modules/nixvim/core`.
- Editor-only plugins stay in this tree. System packages they need (compilers, formatters) belong in `home/develop/` or `pkgs/`.
- `nixvim/obsidian/` and `leetcode.nix` are feature slices. Keep them optional behind the profile that enables them.
