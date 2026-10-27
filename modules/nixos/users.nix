{
  base,
  config,
  lib,
  ...
}:
let
  inherit (config) isContainer app;
  coding = base.group "coding";
  users-host = base.group "users-host";
  data = base.group "data";
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
        users.${app.username} = {
          isSystemUser = true;
          # isNormalUser = false;
          uid = app.uid;
          group = app.username;
          home = app.home;
          createHome = true;
          linger = true;
          shell = base.tools.shell;
        };

        groups.${app.username}.gid = app.uid;
      };
    })

    {
      # users.mutableUsers = false;
    }
  ];
}
