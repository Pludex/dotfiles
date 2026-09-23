{
  profiles.live = {
    home = {
      apps = [
        # "bitwarden"
        # "claude-desktop"
        # "discord"
        # "obsidian"
        # "sklauncher"
        "spotify"
        # "steam"
        "vivaldi"
        # "wps"
      ];

      programs = [
        # "emacs"
        "fastfetch"
        # "firefox"
        # "floorp"
        "nushell"
        "statix"
        # "wezterm"
        # "zsh"

        "atuin"
        "bash"
        "bat"
        "btop"
        "carapace"
        "delta"
        "direnv"
        "eza"
        "fd"
        "fish"
        "fzf"
        "gh"
        "ghostty"
        "git"
        "kitty"
        "lazygit"
        # "mpv"
        "nh"
        # "nix-index"
        # "nix-your-shell"
        "nixvim"
        "packages"
        "ripgrep"
        "starship"
        # "sunix"
        "superfile"
        # "tirith"
        "zoxide"
      ];

      services = [
        "audio-manager"
        "clipse"
        # "espanso"
      ];

      develop = [
        # "dotnet"
      ];

      ides = [
        # "vscode"
        # "rider"
      ];
    };

    nixos = {
      services = [
        # "caddy"
        "envfs"
        # "flatpak"
        # "nginx"
        # "ngrok"
        # "vaultwarden"
      ];
    };
  };
}
