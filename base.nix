{
  config,
  inputs,
  base,
  ...
}:
{
  base.pure = {
    # ── Identity ────────────────────────────────────────────
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
    group = name: base.groups.${name};

    # ── Secrets / keys ──────────────────────────────────────
    age = {
      publicKey = "age1mwp4mujj0cq40sc4yn33el4lxaap86wlrxzhyf73h7ecsm0gx5yqas8pf0";
      # privateKeyPath = "${config.paths.abs.home}/.config/sops/age/keys.txt";
      privateKeyPath = "${config.paths.abs.dataPrivate}/age.dotfiles.keys.txt";
      defaultFile = "${config.paths.data}/main.enc.yaml";
    };

    ssh = {
      pub = builtins.readFile "${config.paths.abs.data}/ssh.pub";
      privateKeyPath = "${config.paths.abs.home}/.ssh/id_ed25519";
    };

    # ── Repo / locale ───────────────────────────────────────
    repoGh = "https://github.com/Pludex/dotfiles";
    timeZone = "Asia/Ho_Chi_Minh";
    locale = "en_US.UTF-8";

    # ── Helpers ─────────────────────────────────────────────
    inherit (config.paths) abs;
    app = name: base.apps.${name} or (throw "app: '${name}' is not defined");

    # ── Glyphs ──────────────────────────────────────────────
    glyphs = {
      nix = {
        logo = " ";
      };

      git = {
        logo = "󰊢 ";
        commit = " ";

        staged = "● ";
        diff = {
          added = " ";
          removed = " ";
          ignored = " ";
          modified = " ";
          renamed = " ";
          untracked = "󰰧 ";
          conflict = "󰰰 ";
        };

        branch = {
          icon = " ";
        };
      };

      level = {
        error = " ";
        warn = " ";
        info = "󰋽 ";
        hint = " ";
        debug = " ";
        trace = "[Trace]";
      };

      lsp = {
        icon = " ";
      };

      prompt = " ";

      border = [
        "╭"
        "─"
        "╮"
        "│"
        "╯"
        "─"
        "╰"
        "│"
      ];

      file = {
        readonly = " ";
        modified = " ";
        newfile = " ";
        unnamed = "[No Name]";
      };
    };

    ignores = [
      ".direnv/"
    ];
  };

  paths = {
    # ── Top-level dirs ──────────────────────────────────────
    flake = inputs.self;
    data = ./data;
    desktops = ./desktops;
    commonDesktop = ./desktops/common;
    emacs = ./emacs;
    hosts = ./hosts;
    libx = ./lib;
    modules = ./modules;
    overlays = ./overlays;
    patches = ./patches;
    pkgs = ./pkgs;
    profiles = ./profiles;

    nixos = {
      root = ./nixos;
      apps = ./nixos/apps;
      containers = ./nixos/containers;
      programs = ./nixos/programs;
      services = ./nixos/services;
      virtualisation = ./nixos/virtualisation;
    };

    home = {
      root = ./home;
      apps = ./home/apps;
      develop = ./home/develop;
      ides = ./home/ides;
      programs = ./home/programs;
      services = ./home/services;
    };

    nixvim = {
      root = ./nixvim;
      languages = ./nixvim/languages;
    };

    # ── Absolute paths on the machine ───────────────────────
    abs = {
      home = "/home/${base.username}";
      workspaces = "/workspaces";
      dotfiles = "${config.paths.abs.workspaces}/dotfiles";
      emacs = "${config.paths.abs.dotfiles}/emacs";
      dotfilesBot = "/workspaces/dotfiles-bot";
      data = "${config.paths.abs.dotfilesBot}/data";
      dataPrivate = "/private";
    };
  };

  # Needs pkgs everywhere
  base.withPkgs = [
    (
      pkgs:
      let
        inherit (pkgs) lib;
      in
      {
        tools = rec {
          shell = pkgs.fish;
          editor = pkgs.myPkgs.editor;
          browser = pkgs.vivaldi;
          # pager = "bat --plain --pager='less -FR'";
          pager = pkgs.bat;
          term = pkgs.ghostty;

          vivaldi = {
            cmdProfileWork = ''${lib.getExe pkgs.vivaldi} --profile-directory="Default" &'';
            cmdProfileSociety = ''${lib.getExe pkgs.vivaldi} --profile-directory="Profile 1" &'';
          };

          shellAliases = {
            cd = "z";
            cat = "bat";
            less = lib.getExe pager;
            nano = lib.getExe editor;
            grep = "grep";
            find = "fd";
            tree = "eza -T";
          };

          envvars = {
            EDITOR = "${lib.getExe editor}";
            BROWSER = vivaldi.cmdProfileWork;
          };
        };
      }
    )
  ];

  # Names, sizes and flags are pkgs-free and also land in pureBase
  base.mixed = [
    (pkgs: {
      fonts = {
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };

        sansSerif = {
          package = pkgs.nerd-fonts.ubuntu-sans;
          name = "UbuntuSans NF";
        };

        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font";
        };

        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };

        sizes = {
          terminal = 9;
        };
      };

      icons = {
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus-Light";
      };

      opacity = {
        terminal = 0.5;
        applications = 0.9;
        desktop = 0.9;
        popups = 0.9;
      };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Original-Classic";
        size = 22;
      };

      base16Scheme = "${pkgs.myPkgs.schemes}/base16/carbonfox.yaml";
      polarity = "dark";
    })
  ];

  base.specialArgs = [
    { inherit inputs; }
  ];
}
