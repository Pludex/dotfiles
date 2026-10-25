{
  profiles.hermes = {
    nixos = {
      services = [
        "hermes"
      ];
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
    };
  };
}
