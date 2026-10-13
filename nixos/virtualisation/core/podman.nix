{ base, ... }:
{
  virtualisation.podman.enable = true;
  users.users.${base.username} = {
    linger = true;
    extraGroups = [ "podman" ];
  };
}
