{
  profiles.desktop = {
    home = {

      ai = [
        "claude-desktop"
        "aider"
      ];
      apps = [
        "bitwarden"
        "discord"
        "obsidian"
        "sklauncher"
        "spotify"
        "steam"
        "vivaldi"
        "wps"
        "zalo"
      ];

      programs = [
        "fastfetch"
        # "firefox"
        # "floorp"
        "nushell"
        "statix"
        "warp"
        "wezterm"
        "zsh"

        "atuin"
        "bash"
        "bat"
        "btop"
        "carapace"
        "delta"
        "direnv"
        "emacs"
        "eza"
        "fd"
        "fish"
        "fzf"
        "gh"
        "ghostty"
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
        "tirith"
        "yazi"
        "zoxide"
      ];

      services = [
        "audio-manager"
        # "espanso"
      ];

      develop = [
        "dotnet"
      ];

      ides = [
        "vscode"
        "rider"
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
        "win10"
      ];
    };
  };
}
