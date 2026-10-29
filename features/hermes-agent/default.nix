{
  inputs,
  config,
  base,
  ...
}:
{
  features = {
    hermes-agent = {
      modules = {
        nixos = [
          ./hermesctl
          ./container.nix
        ];

        home = [
          ./desktop.nix
        ];
      };
    };

    # hermes-agent-podman = {
    #   modules = {
    #     home = [
    #       ./podman
    #     ];
    #   };
    # };
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
        ./backend.nix
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
  extraBase.apps.hermes-agent = rec {
    port = 8642;
    baseUrl = "http://127.0.0.1:${toString port}";
    dashboardPort = 9119;
    dashboardUrl = "http://127.0.0.1:${toString dashboardPort}";

    data = "/workspaces/hermes";

    username = "hermes";
    uid = 2000;
    home = "/home/hermes";

    age = {
      publicKey = "age158va6e0syfx3cm2rwj7un2yu7p8zwqnxdqtedk5tkwk3g7nuxflspzs0em";
      privateKeyPath = "/private/hermes.age-key.txt";
      defaultFile = "${config.paths.data}/hermes.enc.yaml";
    };

    nixosConfigs = {
      container = inputs.self.nixosConfigurations.hermes-agent;
    };

    users.host = {
      username = "hermes-host";
      home = "/var/lib/hermes-host";
      uid = 1002;
    };

    modules.nixos =
      let
        coding = config.base.group "coding";
      in
      {
        users.groups.coding.gid = coding.gid;
        users.users.${username}.extraGroups = [ "coding" ];
        users.users.root.extraGroups = [ "coding" ];
      };

    user = name: (base.app "hermes-agent").users.${name};
  };

  perSystem =
    { inputs', ... }:
    let
      hermes =
        let
          hermesPkgs = inputs'.hermes-agent.packages;
          hermesFull = hermesPkgs.default.override {
            version = "0.22.5";
          };
        in
        inputs'.hermes-agent.packages
        // {
          full = hermesFull;
          default = hermesFull;
          desktop = hermesFull.hermesDesktop;
          tui = hermesFull.hermesTui;
          # web = hermesFull.hermesWeb;
          # webapp = hermesFull.hermesWebapp;
        };
    in
    {
      packagesOfInputs = {
        inherit hermes;
      };

      ciPackages = {
        inherit hermes;
      };
    };
}
