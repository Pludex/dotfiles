{
  base,
  inputs,
  lib,
  ...
}:
{
  nix.settings = {
    auto-optimise-store = true;
    trusted-users = [ base.username ];
    accept-flake-config = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-substituters = lib.mkForce [
      "https://pludex.cachix.org"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = lib.mkForce [
      "pludex.cachix.org-1:iZbrMY/10HM5BQPXeIIHkGoDc4boLuSZYiZuPhIn9P8="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
    randomizedDelaySec = "45min";
  };

  nix.firewall = {
    enable = true;
    allowLoopback = true;
    allowNonTCPUDP = false;
    allowPrivateNetworks = false;
  };

  nix.registry.nixpkgs = lib.mkDefault {
    to = {
      type = "flake";
      flake = inputs.self;
    };
  };
}
