{
  extraBase.apps.omniroute = rec {
    loopback = "127.0.0.1";
    port = 20128;
    baseUrl = urlFrom loopback;
    # Same service seen from another address (e.g. a guest reaching the host)
    urlFrom = host: "http://${host}:${toString port}";
    listenHost = "localhost";
    data = "/workspaces/omniroute";

    container = rec {
      name = "omniroute";
      unit = "podman-${name}.service";
      data = "/app/data";
      image = rec {
        repo = "localhost/omniroute";
        tag = "web";
        ref = "${repo}:${tag}";
      };
    };
  };

  features.omniroute.modules = {
    home = [
      # ./backend.module.nix
      ./backend.nix
    ];
  };
}
