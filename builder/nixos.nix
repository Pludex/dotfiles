{
  mkPkgs,
  mkNixosModules,
  args,
  mkHome,
}:
let
  inherit (args) inputs;

  configOptions =
    { lib, ... }:
    let
      mkStrOption =
        description:
        lib.mkOption {
          type = lib.types.str;
          inherit description;
        };
    in
    {
      options = {
        desktop = mkStrOption "Desktop name currently in use";
        profile = mkStrOption "Profile name currently in use";
        host = mkStrOption "Host name currently in use";
        name = mkStrOption "Config name currently in use";
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
      pkgs = mkPkgs { inherit system; };

      modules =
        mkNixosModules {
          inherit host profile desktop;
          extraNixosModules = extraModules;
        }
        ++ [
          inputs.home-manager.nixosModules.home-manager
          configOptions
          {
            inherit
              desktop
              profile
              host
              name
              ;
          }
          # Overlays are baked into mkPkgs, so nixpkgs.config/overlays set by
          # other modules are ignored once nixpkgs.pkgs is set.
          { nixpkgs.pkgs = pkgs; }
          # Reads profile/desktop/name back from this config.
          ({ config, ... }: { home-manager = mkHome { inherit config; }; })
        ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      inherit modules;
      # `args` has no pkgs (includePkgs' = false), so it can't clash with
      # nixpkgs.pkgs.
      specialArgs = args;
    };
}
