{ config, lib, ... }:
let
  inherit (config) isContainer;
in
{
  networking = lib.mkMerge [
    { hostName = config.name; }

    (lib.mkIf (!isContainer) {
      nameservers = [
        "1.1.1.1"
        "8.8.8.8"
        "2606:4700:4700::1111"
        "2001:4860:4860::8888"
      ];

      firewall = {
        enable = true;
        allowedTCPPorts = [
          22
          80
          443
        ];
        allowedUDPPorts = [ 51820 ]; # WireGuard
      };

      nftables = {
        enable = true;
        flushRuleset = false;
      };

      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
        wifi.backend = "iwd";
      };

      wireless.enable = false;
    })

    (lib.mkIf isContainer {
      useDHCP = false;
      firewall.enable = false;
      nftables.enable = false;
      networkmanager.enable = false;
      resolvconf.enable = false;
    })
  ];

  services.resolved = lib.mkIf (!isContainer) {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNSOverTLS = "true";
      Domains = [ "~." ];
      FallbackDNS = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };
  };
}
