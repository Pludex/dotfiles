{
  profiles.hermes = {
    nixos = {
    };
    home = {
      programs = [
        "atuin"
        "bash"
        "bat"
        "delta"
        "direnv"
        "eza"
        "fd"
        "fish"
        "fzf"
        "packages"
        "ripgrep"
        "starship"
        "zoxide"
      ];

      services = [
        "hermes"
      ];
    };

    # modules = [ "sops-os" ];
  };
}
