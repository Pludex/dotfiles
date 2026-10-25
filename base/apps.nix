{ config, ... }:
{
  extraBase = {
    apps = {
      hermes-agent = rec {
        port = 8642;
        urlBase = "http://127.0.0.1:${toString port}";
        abs = {
          data = "/workspaces/hermes";
        };
      };

      omniroute = rec {
        port = 20128;
        urlBase = "http://127.0.0.1:${toString port}";
        abs = {
          data = "/workspaces/omniroute";
        };
      };
    };
    appOf = name: config.base.apps.${name};
  };
}
