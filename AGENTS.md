
Welcome! This repository is a highly customized, Flake-based Nix/NixOS monorepo. It manages system configurations, user environments (Home Manager), editor setups (Nixvim & Emacs), and custom packages/daemons.

This document serves as a map and set of guidelines for AI agents and developers working on this codebase.

---

## 1. Repository Structure Overview

Here is a high-level breakdown of the directory layout:

```text
.
├── base/                     # Base Nix configurations, tools, and glyphs
├── builder/                  # Nix builders for profiles, home, nixos, and nixvim
├── data/                     # Encrypted secrets (SOPS/Age) and static data (SSH keys, etc.)
├── desktops/                 # Desktop Environment / Window Manager configs (MangoWM, Niri, Plasma 6)
│   ├── common/               # Shared desktop utilities (clipse, fuzzel)
│   ├── MangoWM/              # Custom Wayland/Waybar-based window manager setup
│   └── niri/                 # Niri scroll-window-manager configuration
├── emacs/                    # Custom Emacs configuration (init.el, packages.el, themes)
├── home/                     # Home Manager modules grouped by category (apps, develop, programs, services)
├── hosts/                    # Host-specific NixOS configurations (e.g., dp7530, live ISO)
├── lib/                      # Custom Nix library functions and helpers
├── modules/                  # Reusable Nix modules
│   ├── flake/                # Flake-level modules (e.g., Nixvim configurations)
│   ├── home/                 # Reusable Home Manager modules (GTK, input methods, style, etc.)
│   ├── nixos/                # Reusable NixOS modules (audio, bluetooth, security, users, etc.)
│   └── nixvim/               # Reusable Nixvim modules (core, edit, languages, UI, themes)
├── nixos/                    # System-level services (caddy, nginx, vaultwarden, etc.)
├── nixvim/                   # Language-specific Nixvim configurations and plugins
├── overlays/                 # Nixpkgs overlays (dotnet, neovide, nushell)
├── pkgs/                     # Custom packages, scripts, and daemons
│   ├── audio-manager/        # Python-based MPRIS audio ducking daemon
│   ├── vaultwarden-sync/     # Python-based backup/sync tool for Vaultwarden
│   ├── vivaldi-sync/         # Nushell-based Vivaldi configuration sync tool
│   └── patchy-cnb/           # Rust-based NAPI-RS input emulator and window utility
└── profiles/                 # High-level configuration profiles (desktop, live, ecode)
```

---

## 2. Key Components & Technologies

### NixOS & Home Manager
* **Flake-based**: The entry point is `flake.nix` which outputs system configurations, home configurations, and packages.
* **Modular Design**: System-level configurations are in `hosts/` and import modules from `modules/nixos/`. User-level configurations are in `desktops/` and `home/`, importing modules from `modules/home/`.
* **Styling**: Centralized styling options are managed via `modules/home/style.nix`.

### Nixvim (Neovim via Nix)
* Neovim is configured declaratively using **Nixvim**.
* Core options, keymaps, and global settings are in `modules/nixvim/core/`.
* Plugins are modularized under `modules/nixvim/` (e.g., `ui/`, `git/`, `file/`, `languages/`).
* Language-specific LSP, formatters, and treesitter configurations are located in `nixvim/languages/`.

### Custom Packages (`pkgs/`)
This repository contains several custom-built applications and scripts:
1. **`audio-manager`**: A Python daemon (`daemon.py`) that monitors MPRIS players (via `playerctl`) and performs smooth volume ducking based on active players and metadata rules.
2. **`vaultwarden-sync`**: A Python script (`vaultwarden-sync.py`) that automates backing up, encrypting (via Age), and syncing Vaultwarden data with a Git repository.
3. **`patchy-cnb`**: A Rust-based Node-API (`napi-rs`) library (`src/lib.rs`) providing low-level OS interactions like input emulation, window management, and monitor detection.
4. **`vivaldi-sync`**: A Nushell script (`vivaldi-sync.nu`) to backup and restore Vivaldi browser profiles.

### Secrets Management
* Secrets are managed using **SOPS** and **Age**.
* Encrypted files are stored in `data/` (e.g., `data/main.enc.yaml`, `data/api-keys.enc.yaml`).
* Decryption keys and rules are configured in `.sops.yaml` and `.envrc`.

---

## 3. Guidelines for AI Agents

When assisting with this repository, please adhere to the following rules:

### 1. Modifying Existing Files
* **Do not modify existing files directly** unless the user has explicitly added them to the chat context or requested changes to them.
* If a change requires editing an existing file that is not currently in the chat, **ask the user to add it first**.
* Only suggest changes to files that are *directly* responsible for the requested feature or fix. Avoid proposing unnecessary modifications to configuration files that only provide context.

### 2. Creating New Files
* When creating new files, place them in the appropriate directory matching the repository structure (e.g., new Nixvim language modules in `nixvim/languages/`, new Home Manager programs in `home/programs/`).
* Always output the entire content of any new file using the strict file listing format.

### 3. Code Style & Best Practices
* **Nix**: Use clean, idiomatic Nix. Prefer `lib.mkIf`, `lib.mkOption`, and structured module options where appropriate.
* **Python**: Follow PEP 8. Use type hints and async/await patterns where established (e.g., in `audio-manager`).
* **Rust**: Ensure code in `pkgs/patchy-cnb` is idiomatic, safe, and matches the NAPI-RS bindings defined in `index.d.ts`.
* **Shell/Nushell**: Prefer Nushell (`.nu`) or robust Bash scripts with proper error handling (`set -euo pipefail`).
