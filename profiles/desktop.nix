{
  profiles.desktop = {
    desktop = "hyprland";
    modules = {
      home = {
        apps = [
          "bitwarden"
          "discord"
          "obsidian"
          "sklauncher"
          "soundcloud"
          "spotify"
          "vivaldi"
          "wps"
          "zalo"
        ];

        programs = [
          "fastfetch"
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
          "ripgrep"
          "starship"
          "superfile"
          "yazi"
          "zoxide"
          "vscode"
        ];

        services = [
          "audio-manager"
        ];

        develop = [
          "dotnet"
        ];

        packages = [
          "desktop"
          "nix-dev"
          "utils"
        ];
      };

      nixos = {
        services = [
          "envfs"
          "ngrok"
          "vaultwarden"
        ];

        virtualisation = [
          "podman"
        ];

        apps = [
          "steam"
        ];
      };
    };

    features = [
      "hermes-agent"
      "omniroute"
    ];
  };
}
