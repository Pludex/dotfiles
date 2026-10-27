{ config, ... }:
let
  hp = config.base.paths.home;
  np = config.base.paths.nixos;
  vp = config.base.paths.nixvim;
in
{

  imports = [
    ./ci.nix
    ./desktop.nix
    ./editor.nix
    ./hermes.nix
    ./leetcode.nix
    ./live.nix
  ];

  # Every handler here has the same shape: subkey name -> the matching
  # `base.paths.<category>.<subkey>` dir, entry name appended as-is.
  # profiles.nix tries `<that>.nix` then `<that>/` (default.nix), so a
  # subkey can mix flat files ("atuin") and directories ("fastfetch")
  # freely without the handler needing to know which is which.
  profilesImportHandlers = {
    home = {
      ai = n: hp.ai + "/${n}";
      apps = n: hp.apps + "/${n}";
      programs = n: hp.programs + "/${n}";
      services = n: hp.services + "/${n}";
      develop = n: hp.develop + "/${n}";
      ides = n: hp.ides + "/${n}";
    };

    homeRoot = {
      ai = n: hp.ai + "/${n}";
      apps = n: hp.apps + "/${n}";
      programs = n: hp.programs + "/${n}";
      services = n: hp.services + "/${n}";
      develop = n: hp.develop + "/${n}";
      ides = n: hp.ides + "/${n}";
    };

    nixos = {
      services = n: np.services + "/${n}";
      virtualisation = n: np.virtualisation + "/${n}";
      apps = n: np.apps + "/${n}";
      containers = n: np.containers + "/${n}";
      programs = n: np.programs + "/${n}";
    };

    nixvim = {
      languages = n: vp.languages + "/${n}";
      root = n: vp.root + "/${n}";
    };
  };

  modules.sops-os = {
    home =
      { lib, ... }:
      {
        options.os-sops = {
          secrets = lib.mkOption {
            type = lib.types.attrsOf lib.types.raw;
            default = { };
            description = "Passthrough to NixOS sops.secrets";
          };
          templates = lib.mkOption {
            type = lib.types.attrsOf lib.types.raw;
            default = { };
            description = "Passthrough to NixOS sops.templates";
          };
        };
      };

    nixos =
      { config, lib, ... }:
      let
        users = config.home-manager.users;
        collect = attr: lib.mkMerge (lib.mapAttrsToList (_: u: u.os-sops.${attr} or { }) users);
      in
      {
        sops.secrets = collect "secrets";
        sops.templates = collect "templates";
      };
  };
}
