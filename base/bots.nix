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
          defaultFile = "${config.base.paths.data}/hermes.enc.yaml";
        };
      };
    };

    botOf = name: config.base.bots.${name} or (throw "botOf: bot '${name}' is not defined");
  };
}
