{
  extraBase.apps.omniroute = rec {
    loopback = "127.0.0.1";
    # Name other guests use for the host's omniroute (mapped in their /etc/hosts)
    hostname = "omniroute";
    port = 20128;
    # From the host itself
    baseUrl = urlFrom loopback;
    # From a guest that maps `hostname` to the host loopback
    internalUrl = urlFrom hostname;
    # Same service seen from another address
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
