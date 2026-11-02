{
  inputs,
  config,
  base,
  ...
}:
{
  features.hermes-agent.modules = {
    nixos = [
      ./hermesctl/default.nixos.nix
      ./container.nix
    ];
    home = [
      ./hermesctl/default.hm.nix
    ];
  };

  profiles.hermes-agent = {
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
      extraModules = [
        ./backend
        ./tools.nix
      ];
    };
    nixos = { };
  };

  nixos.hermes-agent = {
    profile = "hermes-agent";
    host = "container";
    desktop = "tty";
  };

  myPkgs.oh-my-hermes.path = ./oh-my-hermes.nix;

  perSystem =
    { inputs', ... }:
    let
      hermesFull = inputs'.hermes-agent.packages.default.override {
        version = "0.22.5";
      };
      hermes = inputs'.hermes-agent.packages // {
        full = hermesFull;
        default = hermesFull;
        desktop = hermesFull.hermesDesktop;
        tui = hermesFull.hermesTui;
      };
    in
    {
      packagesOfInputs = { inherit hermes; };
      ciPackages = { inherit hermes; };
    };

  extraBase.apps.hermes-agent =
    let
      coding = config.base.group "coding";
    in
    rec {
      # Network
      loopback = "127.0.0.1";

      ports = {
        api = 8642;
        dashboard = 9119;
      };

      urls = {
        api = "http://${loopback}:${toString ports.api}";
        dashboard = "http://${loopback}:${toString ports.dashboard}";
      };

      network = rec {
        mode = "host"; # "host" | "bridge" | "pasta"
        name = "hermes";
        subnet = "10.89.200.0/24";
        gateway = "10.89.200.1";
        ip = "10.89.200.2";
        # IP inside pasta namespace that maps to host 127.0.0.1 (--map-host-loopback).
        # Choose any RFC-5737 / link-local address not in use on the host.
        pastaHostLoopback = "169.254.1.1";
        # How the guest reaches host services (e.g. OmniRoute)
        hostAddress =
          if mode == "host" then loopback
          else if mode == "pasta" then pastaHostLoopback
          else "host.containers.internal";
        # Address the guest's servers must bind to for published ports to work
        bindAddress = if mode == "host" then loopback else "0.0.0.0";
      };

      # GitHub bot identity
      github = {
        appId = 5526907;
        clientId = "Iv23liV3f0Mwh6ersI3Z";
        slug = "hermes-agent-pludex";
        botUserId = 349787113;
      };
      name = "Hermes-Agent-Pludex[bot]";
      email = "${toString github.botUserId}+${github.slug}[bot]@users.noreply.github.com";

      # Guest user
      username = "hermes";
      uid = 2000;
      home = "/home/${username}";
      data = "/workspaces/hermes";

      age = rec {
        publicKey = "age158va6e0syfx3cm2rwj7un2yu7p8zwqnxdqtedk5tkwk3g7nuxflspzs0em";
        privateDir = "/private";
        privateKeyPath = "${privateDir}/${username}.age-key.txt";
        defaultFile = "${config.paths.data}/hermes.enc.yaml";
        sopsSecret = "age-keys/${username}";
      };

      # Container
      container = rec {
        name = "hermes";
        serviceName = "podman-${name}";
        unit = "${serviceName}.service";
        nixosConfig = inputs.self.nixosConfigurations.hermes-agent;
        image = rec {
          name = "hermes-agent";
          tag = "latest";
          ref = "${name}:${tag}";
        };
        appDir = "/app";
        data = "${appDir}/data";
        workspaces = "/workspaces";
      };

      # Users and id mapping
      users = {
        host = {
          username = "hermes-host";
          group = "users-host";
          home = "/var/lib/hermes-host";
          uid = 1002;
          gid = 1002;
          subUid = {
            start = 200000;
            count = 65536;
          };
          subGid = {
            start = 200000;
            count = 65536;
          };
        };

        container = {
          # container uid N (N >= 1) maps to host subuid start + N - 1
          uid = users.host.subUid.start + uid - 1;
        };
      };

      # podman --uidmap/--gidmap segments: container id -> intermediate id
      idmap = {
        uid = {
          root = {
            inner = 0;
            outer = 0;
            count = 1;
          };
          subordinate = {
            inner = 1;
            outer = 1;
            count = users.host.subUid.count;
          };
        };
        gid = {
          root = {
            inner = 0;
            outer = 0;
            count = 1;
          };
          belowCoding = {
            inner = 1;
            outer = 2;
            count = coding.gid - 1;
          };
          coding = {
            inner = coding.gid;
            outer = 1;
            count = 1;
          };
          aboveCoding = {
            inner = coding.gid + 1;
            outer = coding.gid + 1;
            count = users.host.subGid.count + 1 - coding.gid;
          };
        };
      };

      # Guest NixOS bits
      modules.nixos = {
        users.groups.coding.gid = coding.gid;
        users.users.${username}.extraGroups = [ "coding" ];
        users.users.root.extraGroups = [ "coding" ];
      };

      user = name: (base.app "hermes-agent").users.${name};
    };
}
