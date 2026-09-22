{
  pkgs,
  base,
  config,
  ...
}:
{
  users.users.${base.username} = {
    isNormalUser = true;
    description = "user main";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs."${base.tools.shell}";
    home = base.abs.home;
    hashedPasswordFile = config.sops.secrets."hashedPassword".path;
  };
}
