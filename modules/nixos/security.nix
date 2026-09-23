{
  security.sudo = {
    enable = true;

    extraConfig = ''
      Defaults timestamp_timeout=60
      Defaults env_keep += "PATH"
    '';
  };
}
