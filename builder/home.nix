{
  mkPkgs,
  mkHomeModules,
  args,
}:
let
  inherit (args) inputs base;

  configOptions =
    { lib, ... }:
    {
      options.standalone = lib.mkOption {
        type = lib.types.bool;
        description = "When building home-manager in standalone mode, it evaluates to true, and vice versa";
      };

      options.profile = lib.mkOption {
        type = lib.types.str;
        description = "Profile name currently in use";
      };

      options.desktop = lib.mkOption {
        type = lib.types.str;
        description = "Desktop name currently in use";
      };

      options.name = lib.mkOption {
        type = lib.types.str;
        description = "Config name currently in use";
      };
    };

  # Shared by both modes so they always evaluate the same module list.
  mkModules =
    {
      standalone,
      name,
      profile,
      desktop,
      extraHomeModules ? [ ],
    }:
    mkHomeModules {
      inherit profile desktop extraHomeModules;
    }
    ++ [
      configOptions
      {
        inherit
          standalone
          profile
          desktop
          name
          ;
      }
    ];
in
{
  mk =
    {
      name,
      system,
      profile,
      desktop,
      extraModule ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs { inherit system; };
      # specialArgs are resolved before `config`, so modules can use them
      # in `imports` (e.g. `inputs.sops-nix.homeManagerModules.sops`).
      extraSpecialArgs = args;
      modules = mkModules {
        inherit name profile desktop;
        standalone = true;
        extraHomeModules = extraModule;
      };
    };

  mkNonStandalone =
    { config, ... }:
    {
      # pkgs (with all overlays) comes from the NixOS config, so `args` must
      # not carry its own pkgs.
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      extraSpecialArgs = args;

      users.${base.username}.imports = mkModules {
        inherit (config) name profile desktop;
        standalone = false;
      };
    };
}
