{
  mkPkgs,
  mkHomeModules,
  args,
}:
let
  inherit (args) inputs base;

  configOptions = { lib, ... }: {
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
    let
      pkgs = mkPkgs {
        inherit system;
      };

      modules =
        mkHomeModules {
          inherit profile desktop;
          extraHomeModules = extraModule;
        }
        ++ [
          configOptions
          {
            standalone = true;
            inherit profile desktop name;
          }
        ];
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit modules pkgs;
      extraSpecialArgs = args;
    };

  mkNonStandalone =
    { config, ... }:
    let
      modules =
        (mkHomeModules {
          inherit (config) profile desktop;
          extraHomeModules = [ ];
        })
        ++ [
          configOptions
          {
            standalone = false;
            inherit (config) profile desktop name;
          }
        ];
    in
    {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";

      extraSpecialArgs = args;

      users.${base.username} = {
        imports = modules;
      };
    };
}
