{
  # configuration.nix
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports for Steam Local Network Game Transfers
  };

  # Ensure 32-bit graphics drivers are enabled
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
