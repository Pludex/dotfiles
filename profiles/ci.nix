{
  profiles.ci.use = {
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
