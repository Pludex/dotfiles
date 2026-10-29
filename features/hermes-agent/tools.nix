{ config, lib, ... }:
let
  inherit (config) app;
in
{
  programs.git = lib.mkForce {
    enable = true;
    settings = {
      user = {
        inherit (app) name email;
      };
    };
  };
}
