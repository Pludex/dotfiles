{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    config = {
      load_dotenv = true;
      hide_env_diff = true;
    };
  };
}
