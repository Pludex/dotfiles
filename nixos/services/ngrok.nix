{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.ngrok ];
}
