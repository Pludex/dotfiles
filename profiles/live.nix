{
  profiles.live.use = {
    home = {
      apps = [
        "spotify"
        "vivaldi"
      ];

      programs = [
        "fastfetch"
        "nushell"
        "statix"

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
        "nh"
        "nixvim"
        "ripgrep"
        "starship"
        "superfile"
        "zoxide"
      ];

      services = [
        "audio-manager"
        "clipse"
      ];

      develop = [
        # "dotnet"
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
      ];
    };
  };
}
