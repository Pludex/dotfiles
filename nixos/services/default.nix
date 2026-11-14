{
  modules.nixos.services = {
    caddy = {
      services.caddy.enable = false;
    };

    envfs = {
      services.envfs.enable = true;
    };

    flatpack = {
      services.flatpak.enable = true;
    };

    nginx = {
      services.nginx = {
        enable = false;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
      };
    };

    ngrok =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.ngrok ];
      };

    vaultwarden = ./vaultwarden.nix;
  };
}
