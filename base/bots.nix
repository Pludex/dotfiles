{ config, ... }:
{
  extraBase = {
    bots = {
      hermes = {
        username = "hermes";
        abs.home = "/home/hermes";
        uid = 2000;

        age = {
          publicKey = "age1sa0pkf0whq7r2agrdzckec0w02c6tsremlvl7zha99h0thqmkvyst43n25";
          privateKeyPath = "/private/hermes.age-key.txt";
          defaultFile = "${config.paths.data}/hermes.enc.yaml";
        };

        modules.nixos =
          let
            inherit (config) base;
            coding = base.groupOf "coding";
          in
          {
            users.groups.coding.gid = coding.gid;
            users.users.hermes.extraGroups = [ "coding" ];
            users.users.root.extraGroups = [ "coding" ];
          };
      };
    };

    botOf = name: config.base.bots.${name} or (throw "botOf: bot '${name}' is not defined");
  };
}
