{
  base,
  pkgs,
  lib,
  meta,
  inputs,
  ...
}:
let
  inherit (base) libx;

  app = libx.tryOr (base.app meta.name) null;
  ageSource = if meta.isHeadless then app.age else base.age;
in
{
  imports = [
    ./keyboard
    ./networking.nix
    ./nix-config.nix
    ./users.nix
    ./desktop.nix
    ./systemd.nix

    app.modules.nixos or { }
    inputs.sops-nix.nixosModules.sops
  ];

  options.app = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    default = app;
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

    (lib.mkIf (!meta.isContainer) (
      let
        hub = base.group "hub";
        secrets = base.group "secrets";
      in
      {
        tmpfiles = {
          ${base.abs.hub} = {
            user = base.username;
            group = "hub";
            mode = "550";
          };

          ${base.abs.secrets} = {
            user = base.username;
            group = "secrets";
            mode = "770";
            type = "d";
          };

          ${base.abs.workspaces} = {
            user = base.username;
            group = "coding";
            mode = "770";
            type = "d";
          };

          ${base.abs.dotfiles-ref} = {
            user = base.username;
            mode = "555";
          };
        };

        users = {
          groups = {
            inherit hub secrets;
          };

          users.${base.username} = {
            extraGroups = [ "secrets" ];
          };
        };

        systemd.services.systemd-tmpfiles-setup.unitConfig.RequiresMountsFor = [ "/hub" ];

        fileSystems."/hub/dotfiles" = {
          device = "/hub/workspaces/dotfiles";
          fsType = "none";
          options = [
            "bind"
            "ro"
          ];
        };
      }
    ))
  ];
}
