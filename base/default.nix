{ config, inputs, ... }:
{
  extraBase = {
    name = "Pludex";
    username = "pbcdev"; # TODO: rename to pludex

    email = {
      main = "pbc210.dev@gmail.com";
      sub = "baochaupham4096@gmail.com";
    };

    age = {
      publicKey = "age1mwp4mujj0cq40sc4yn33el4lxaap86wlrxzhyf73h7ecsm0gx5yqas8pf0";
      privateKeyPath = "${config.paths.abs.home}/.config/sops/age/keys.txt";
    };

    ssh = {
      pub = builtins.readFile "${config.paths.abs.data}/ssh.pub";
      privateKeyPath = "${config.paths.abs.home}/.ssh/id_ed25519";
    };

    repoGh = "https://github.com/Pludex/nix-config";

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
      ai = ../home/ai;
    };

    nixvim = {
      root = ../nixvim;
      languages = ../nixvim/languages;
    };

    abs = {
      home = "/home/${config.base.username}";
      dotfiles = "/workspaces/nix-config";
      emacs = "${config.paths.abs.dotfiles}/emacs";
      dotfilesBot = "/workspaces/nix-config-bot";
      data = "${config.paths.abs.dotfilesBot}/data";
    };
  };

  imports = [
    ./ignores.nix
    ./glyphs.nix
    ./tools.nix
  ];
}
