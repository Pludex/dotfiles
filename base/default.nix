{ inputs, ... }:
rec {
  name = "PBCDev210";
  username = "pbcdev"; # TODO: rename to pbcdev210

  email = {
    main = "pbc210.dev@gmail.com";
    sub = "baochaupham4096@gmail.com";
  };

  tools = import ./tools.nix;

  glyphs = import ./glyphs.nix;
  ignores = import ./ignores.nix;

  age = {
    publicKey = "age1mwp4mujj0cq40sc4yn33el4lxaap86wlrxzhyf73h7ecsm0gx5yqas8pf0";
    privateKeyPath = "${paths.home}/.config/sops/age/keys.txt";
  };

  ssh = {
    pub = builtins.readFile "${paths.data}/ssh.pub";
    privateKeyPath = "${paths.home}/.ssh/id_ed25519";
  };

  repoGh = "https://github.com/pbcdev210/nix-config";

  flake = inputs.self;
  assets = ../assets;
  desktops = "${flake}/desktops";
  profiles = "${flake}/profiles";
  hosts = "${flake}/hosts";
  data = "${flake}/data";
  modules = "${flake}/modules";
  pkgs = "${flake}/pkgs";
  overlays = "${flake}/overlays";
  emacs = "${flake}/emacs";

  nixos = rec {
    root = "${flake}/nixos";
    services = "${root}/services";
    virtualisation = "${root}/virtualisation";
  };

  home = rec {
    root = "${flake}/home";
    programs = "${root}/programs";
    services = "${root}/services";
    develop = "${root}/develop";
    apps = "${root}/apps";
    ides = "${root}/ides";
  };

  nixvim = rec {
    root = "${flake}/nixvim";
    languages = "${root}/languages";
  };

  paths = rec {
    home = "/home/${username}";
    dotfiles = "/workspaces/nix-config";
    dotfilesBot = "/workspaces/nix-config-bot";
    data = "${dotfilesBot}/data";
  };

  timeZone = "Asia/Ho_Chi_Minh";
  locale = "en_US.UTF-8";
}
