{
  mkPkgs,
  mkNixosModules,
  args,
  mkHome,
}:
let
  inherit (args) inputs;

  configOptions = { lib, ... }: {

    options.desktop = lib.mkOption {
      type = lib.types.str;
      description = "Desktop name currently in use";
    };

    options.profile = lib.mkOption {
      type = lib.types.str;
      description = "Profile name currently in use";
    };

    options.host = lib.mkOption {
      type = lib.types.str;
      description = "Host name currently in use";
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
      host,
      name,
      system,
      profile,
      desktop,
      extraModules ? [ ],
    }:
    let
      pkgs = mkPkgs {
        inherit system;
      };
      modules =
        mkNixosModules {
          inherit host profile desktop;
          extraNixosModules = extraModules;
        }
        ++ [
          configOptions
          {
            inherit
              desktop
              profile
              host
              name
              ;
          }
          ({ config, ... }: {
            imports = with inputs; [ home-manager.nixosModules.home-manager ];
            home-manager = mkHome { inherit config; };
          })
        ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit modules pkgs;
      specialArgs = args;
    };
}
