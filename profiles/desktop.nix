{ base, ... }:
{
  profiles.desktop = {
    home = {
      apps = [
        "bitwarden"
        "discord"
        "obsidian"
        "sklauncher"
        "spotify"
        # "steam"
        "vivaldi"
        "wps"
        "zalo"
      ];

      programs = [
        "fastfetch"
        # "firefox"
        # "floorp"
        "nushell"
        "quiz-bot"
        "statix"
        "warp"
        "wezterm"
        "zsh"

        "atuin"
        "bash"
        "bat"
        "btop"
        "carapace"
        "cava"
        # "claude-code"
        # "claude-desktop"
        "delta"
        "direnv"
        "emacs"
        "eza"
        "fd"
        "fish"
        "fzf"
        "gh"
        "ghostty"
        "hermes-desktop"
        "kitty"
        "lazygit"
        "mpv"
        "nh"
        "nix-index"
        "nix-your-shell"
        "nixvim"
        "packages"
        "ripgrep"
        "starship"
        # "sunix"
        "superfile"
        # "tirith"
        "yazi"
        "zoxide"
      ];

      services = [
        "audio-manager"
        "omniroute"
        # "espanso"
      ];

      develop = [
        "dotnet"
      ];

      ides = [
        "vscode"
        "rider"
      ];

      extraModules = [
      ];
    };

    nixos = {
      services = [
        # "caddy"
        "envfs"
        # "flatpak"
        # "nginx"
        "ngrok"
        "vaultwarden"
      ];

      virtualisation = [
        "core/libvirt"
        "core/podman"
        "win10"
      ];

      containers = [
        "hermes"
      ];

      extraModules = [
      ];

      apps = [
        "steam"
      ];
      programs = [
        "hermesctl"
      ];
    };
  };
}
