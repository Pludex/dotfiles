{
  config,
  inputs,
  base,
  ...
}:
{
  extraBase = {
    name = "Pludex";
    username = "pludex";
    uid = 1001;
    gid = 100;

    email = {
      main = "pbc210.dev@gmail.com";
      sub = "baochaupham4096@gmail.com";
    };

    groups = {
      coding.gid = 1200;
      users-host.gid = 1002;
      data.gid = 1201;
    };
    groupOf = name: config.base.groups.${name};

    age = {
      publicKey = "age1mwp4mujj0cq40sc4yn33el4lxaap86wlrxzhyf73h7ecsm0gx5yqas8pf0";
      # privateKeyPath = "${config.paths.abs.home}/.config/sops/age/keys.txt";
      privateKeyPath = "${config.paths.abs.dataPrivate}/age.dotfiles.keys.txt";
    };

    ssh = {
      pub = builtins.readFile "${config.paths.abs.data}/ssh.pub";
      privateKeyPath = "${config.paths.abs.home}/.ssh/id_ed25519";
    };

    repoGh = "https://github.com/Pludex/dotfiles";

    timeZone = "Asia/Ho_Chi_Minh";
    locale = "en_US.UTF-8";

    inherit (config.paths) abs;
  };

  paths = {
    flake = inputs.self;
    desktops = ../desktops;
    commonDesktop = ../desktops/common;
    profiles = ../profiles;
    hosts = ../hosts;
    data = ../data;
    modules = ../modules;
    pkgs = ../pkgs;
    overlays = ../overlays;
    emacs = ../emacs;
    libx = ../lib;
    patches = ../patches;

    nixos = {
      root = ../nixos;
      services = ../nixos/services;
      virtualisation = ../nixos/virtualisation;
      apps = ../nixos/apps;
      containers = ../nixos/containers;
      programs = ../nixos/programs;
    };

    home = {
      root = ../home;
      programs = ../home/programs;
      services = ../home/services;
      develop = ../home/develop;
      apps = ../home/apps;
      ides = ../home/ides;
      ai = ../home/ai;
    };

    nixvim = {
      root = ../nixvim;
      languages = ../nixvim/languages;
    };

    abs = {
      home = "/home/${config.base.username}";
      workspaces = "/workspaces";
      dotfiles = "${config.paths.abs.workspaces}/dotfiles";
      emacs = "${config.paths.abs.dotfiles}/emacs";
      dotfilesBot = "/workspaces/dotfiles-bot";
      data = "${config.paths.abs.dotfilesBot}/data";
      dataPrivate = "/private";
    };
  };

  extraArgs = {
    inherit (base) inputs libx;
  };

  imports = [
    ./apps.nix
    ./bots.nix
    ./ignores.nix
    ./glyphs.nix
    ./tools.nix
  ];
}
