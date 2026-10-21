{
  base,
  config,
  lib,
  ...
}:
let
  inherit (config) isContainer;
  bot = base.bots.${config.name} or (throw "base.bots.${config.name} is not defined");
in
{
  config = lib.mkMerge [
    (lib.mkIf (!isContainer) {
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

      sops.secrets."hashedPassword" = { };
    })

    (lib.mkIf isContainer {
      users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;

        users.${bot.username} = {
          isSystemUser = true;
          uid = bot.uid;
          group = bot.username;
          home = bot.abs.home;
          createHome = true;
          shell = base.tools.shell;
        };

        groups.${bot.username}.gid = bot.uid;
      };
    })
  ];
}
