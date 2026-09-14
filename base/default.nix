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
  desktops = ../desktops;
  profiles = ../profiles;
  hosts = ../hosts;
  data = ../data;
  modules = ../modules;
  pkgs = ../pkgs;
  overlays = ../overlays;
  emacs = ../emacs;

  nixos = {
    root = ../nixos;
    services = ../nixos/services;
    virtualisation = ../nixos/virtualisation;
  };

  home = {
    root = ../home;
    programs = ../home/programs;
    services = ../home/services;
    develop = ../home/develop;
    apps = ../home/apps;
    ides = ../home/ides;
  };

  nixvim = {
    root = ../nixvim;
    languages = ../nixvim/languages;
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
