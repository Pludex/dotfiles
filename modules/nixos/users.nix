{
  base,
  config,
  ...
}:
{
  users.users.${base.username} = {
    isNormalUser = true;
    description = base.name;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = base.tools.shell;
    home = base.abs.home;
    hashedPasswordFile = config.sops.secrets."hashedPassword".path;
  };
}
