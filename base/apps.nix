{
  extraBase.apps = {
    omniroute = rec {
      port = 20128;
      baseUrl = "http://127.0.0.1:${toString port}";
      data = "/workspaces/omniroute";
    };
  };
}
