{ config, ... }:
let
  hp = config.base.paths.home;
  np = config.base.paths.nixos;
  vp = config.base.paths.nixvim;
in
{

  imports = [
    ./desktop.nix
    ./ecode.nix
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

    nixos = {
      services = n: np.services + "/${n}";
      virtualisation = n: np.virtualisation + "/${n}";
    };

    nixvim = {
      languages = n: vp.languages + "/${n}";
      root = n: vp.root + "/${n}";
    };
  };
}
