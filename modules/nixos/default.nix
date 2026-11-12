{
  base,
  pkgs,
  lib,
  config,
  meta,
  inputs,
  ...
}:
let
  inherit (base) libx;
  inherit (config) isContainer;

  app = libx.tryOr (base.app meta.name) null;
  ageSource = if isContainer then app.age else base.age;
in
{
  imports = [
    ./keyboard
    ./networking.nix
    ./nix-config.nix
    ./users.nix
    ./desktop.nix

    app.modules.nixos or { }
    inputs.sops-nix.nixosModules.sops
  ];

  options = {
    isContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    app = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      default = app;
    };
  };

  config = lib.mkMerge [
    {
      system.stateVersion = "26.05";
      time.timeZone = base.timeZone;
      i18n.defaultLocale = base.locale;
    }

    {
      environment.systemPackages = [
        pkgs.mkcert
        pkgs.nix
      ];

      documentation.man.cache.enable = false;

      programs.fish.enable = true;
      programs.zsh.enable = true;
    }

    {
      security.sudo = {
        enable = true;
        extraConfig = ''
          Defaults timestamp_timeout=60
          Defaults env_keep += "PATH"
          Defaults env_reset,pwfeedback
        '';
      };

      security.wrappers.intel_gpu_top = {
        owner = "root";
        group = "root";
        capabilities = "cap_perfmon+ep";
        source = lib.getExe' pkgs.intel-gpu-tools "intel_gpu_top";
      };
    }

    {
      sops = {
        defaultSopsFile = ageSource.defaultFile;
        age.keyFile = ageSource.privateKeyPath;
        useSystemdActivation = true;
      };
    }
  ];
}
