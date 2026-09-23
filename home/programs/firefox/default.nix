{ pkgs, ... }:
let
  extensions = with pkgs.firefoxAddons; [
    ublock-origin
    bitwarden-password-manager
    enhancer-for-youtube
    tridactyl-vim
  ];

  settings = {
    "extensions.autoDisableScopes" = 0;
  };

in
{
  programs.firefox = {
    enable = true;

    profiles.main = {
      id = 0;
      name = "main";
      path = "0.main";
      isDefault = true;

      extensions = {
        packages = extensions;
      };

      inherit settings;
    };
  };
}
