# treesitter-kanata

[FORK TO https://github.com/postsolar/tree-sitter-kanata]

A Nix flake that packages a Tree-sitter grammar for the Kanata configuration language (kbd), and provides a Home Manager module for easy integration with nixvim.

This README is flake-first: it shows how to add the flake as an input, use the packaged grammar with Home Manager + nixvim, apply the required overlay, and build the grammar standalone.

## Features

- Builds a Tree-sitter grammar for Kanata (`.kbd`) as a Nix package.
- Provides `homeManagerModules.nixvim` — a Home Manager module that registers the Kanata filetype and injects the grammar package directly into nixvim's configuration options.
- Exposes `overlays.default` so you can register the grammar globally as `pkgs.vimPlugins.nvim-treesitter.kanata`.
- Supports multiple platforms (see `packages.<system>.default` outputs).

## Quick start — add the flake as an input

Add the flake to the `inputs` block of your `flake.nix`:

```nix
inputs = {
  kanata-treesitter.url = "github:pbcdev210/treesitter-kanata";
  # ...your other inputs
};
```

Then reference it from `outputs` when you need the overlay or the Home Manager module.

## Usage with Home Manager + nixvim (recommended)

This flake provides a Home Manager module that integrates with nixvim. Import both nixvim's Home Manager module and this flake's `homeManagerModules.nixvim` into your Home Manager configuration. Example:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim.url = "github:nix-community/nixvim"; # or your preferred pin
    kanata-treesitter.url = "github:pbcdev210/treesitter-kanata";
  };

  outputs = { self, nixpkgs, nixvim, kanata-treesitter, ... }:
  let
    system = "x86_64-linux"; # change to your system
    pkgs = import nixpkgs { inherit system; overlays = [ kanata-treesitter.overlays.default ]; };
  in
  {
    homeConfigurations.example = pkgs.lib.homeManagerConfiguration {
      inherit system;
      modules = [
        nixvim.homeManagerModules.nixvim
        kanata-treesitter.homeManagerModules.nixvim
        # your other modules
      ];
      # ...rest of your home-manager configuration
    };
  }
}
```

What the module does for you:
- Recognizes files with the `.kbd` extension and sets the `kanata` filetype.
- Registers the `kanata` grammar with the `nvim-treesitter` plugin, mapped to the `kbd` filetype (the package is made available via the overlay described below).
- Exposes Home Manager options that integrate with nixvim; however, the grammar package itself is provided via the overlay and must be applied where you construct `pkgs`.

## Required: apply the overlay

This flake exposes the built grammar as an overlay at `overlays.default`. You must apply that overlay when you construct `pkgs` so the grammar becomes available as `pkgs.vimPlugins.nvim-treesitter.kanata`. The Home Manager module (`kanata-treesitter.homeManagerModules.nixvim`) only defines configuration options and filetype integration — it does not inject the package into `pkgs` by itself.

Add the overlay where you import `nixpkgs` / construct `pkgs`. Examples for common setups follow.

1) Home Manager (standalone, flake-based `homeConfigurations`)

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  kanata-treesitter.url = "github:pbcdev210/treesitter-kanata";
  nixvim.url = "github:nix-community/nixvim";
};

outputs = { self, nixpkgs, kanata-treesitter, nixvim, ... }:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; overlays = [ kanata-treesitter.overlays.default ]; };
in {
  homeConfigurations.myhome = pkgs.lib.homeManagerConfiguration {
    inherit system;
    modules = [
      nixvim.homeManagerModules.nixvim
      kanata-treesitter.homeManagerModules.nixvim
    ];
    # ...other module config
  };
}
```

2) NixOS system configuration (nixosConfigurations in a flake)

```nix
nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [ ./configuration.nix ];
  configuration = {
    nixpkgs.overlays = [ kanata-treesitter.overlays.default ];
    # ...other system settings
  };
};
```

3) If you import `pkgs` elsewhere (scripts, CI, utilities)

```nix
let
  pkgs = import nixpkgs { inherit system; overlays = [ kanata-treesitter.overlays.default ]; };
in
# now pkgs.vimPlugins.nvim-treesitter.kanata is available
```

Notes
- After applying the overlay, the grammar is available as `pkgs.vimPlugins.nvim-treesitter.kanata` and the Home Manager module options will work as expected.
- The Home Manager module remains useful for filetype registration and wiring the grammar into `programs.nixvim.plugins.treesitter.grammarPackages`, but the overlay is required so the package can be referenced from `pkgs`.

## Using the package standalone (build it)

If you only need the grammar package (no Home Manager), build it directly with `nix` or `nix build`:

```bash
nix build github:pbcdev210/treesitter-kanata#default
```

The `default` output is the Tree-sitter grammar package (the result of `tree-sitter.buildGrammar`) which you can wire into any Neovim/Tree-sitter setup manually.

If you need a system-specific package, use the flake attribute for that system, for example:

```bash
nix build github:pbcdev210/treesitter-kanata#packages.x86_64-linux.default
```

## Flake outputs

- `packages.<system>.default` — the built Tree-sitter grammar for each supported system.
- `overlays.default` — optional overlay to register the grammar globally under `pkgs.vimPlugins.nvim-treesitter.kanata`.
- `homeManagerModules.nixvim` — a Home Manager module that configures nixvim with the Kanata filetype and injects the grammar package.

## Supported platforms

This flake builds the grammar for common platforms. Examples:
- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

(If you need additional platforms, let me know and I can add them to the CI/flake outputs.)

## Requirements

- Nix with flakes enabled.
- Home Manager (if you plan to use the nixvim module).
- You must import `nixvim` separately in your configuration — this flake does not include `nixvim` as an input.

## Development

- The grammar is produced by `tree-sitter` build steps in this flake.
- The overlay simply registers the built grammar into `vimPlugins.nvim-treesitter` so other configs can reference it as `pkgs.vimPlugins.nvim-treesitter.kanata`.

## License

Repo license (if applicable). Add a license file or update this section to match the repository license.

## Contributing

If you'd like to contribute changes to the grammar or the flake, open a PR against this repository.

---
