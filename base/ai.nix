{
  extraBase.ai = {
    hermes-agent = rec {
      port = 8642;
      urlLocal = "http://127.0.0.1:${toString port}";
      abs = {
        data = "/workspaces/hermes";
      };
    };
  };
}
