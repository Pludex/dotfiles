{
  base,
  config,
  lib,
  ...
}:
let
  inherit (config) isContainer bot;
  coding = base.groupOf "coding";
  users-host = base.groupOf "users-host";
  data = base.groupOf "data";
in
{
  config = lib.mkMerge [
    (lib.mkIf (!isContainer) {
      users.users.${base.username} = {
        isNormalUser = true;
        # isSystemUser = false;
        description = base.name;
        group = "users";
        extraGroups = [
          "coding"
          "wheel"
          "networkmanager"
          "data"
        ];
        shell = base.tools.shell;
        home = base.abs.home;
        hashedPasswordFile = config.sops.secrets."hashedPassword".path;
        inherit (base) uid;
      };

      users.users.root = {
        hashedPasswordFile = config.sops.secrets."hashedPassword".path;
      };

      users.groups = {
        coding = { inherit (coding) gid; };
        users-host = { inherit (users-host) gid; };
        data = { inherit (data) gid; };
      };

      sops.secrets."hashedPassword" = { };
    })

    (lib.mkIf isContainer {
      users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;
        users.${bot.username} = {
          isSystemUser = true;
          # isNormalUser = false;
          uid = bot.uid;
          group = bot.username;
          home = bot.abs.home;
          createHome = true;
          linger = true;
          shell = base.tools.shell;
        };

        groups.${bot.username}.gid = bot.uid;
      };
    })

    {
      # users.mutableUsers = false;
    }
  ];
}
