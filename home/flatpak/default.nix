{ inputs, ... }:
{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];
  services.flatpak = {
    uninstallUnmanaged = true;
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "com.valvesoftware.Steam"
      "com.bitwarden.desktop"
      "com.usebottles.bottles"
      "com.discordapp.Discord"
    ];
  };
}
