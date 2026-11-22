{
  profiles.ci.modules = {
    home = {
      programs = [
        "bash"
        "zsh"
        "statix"
        "nh"
        "nix-index"
      ];
    };
    nixos = { };
  };
}
