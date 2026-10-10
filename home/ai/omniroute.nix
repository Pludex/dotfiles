{ config, ... }:
{
  imports = [
    ./modules/omniroute.nix
  ];

  sops.secrets."api-keys/openrouter/omniroute" = { };

  services.omniroute = {
    enable = true;
    providers.openrouter.apiKeyFile = config.sops.secrets."api-keys/openrouter/omniroute".path;
  };
}
