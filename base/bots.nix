{ config, ... }:
{
  extraBase = {
    bots = {
      hermes = {
        username = "hermes";
        abs.home = "/home/hermes";
        uid = 2000;
      };
    };

    botOf = name: config.base.bots.${name} or (throw "botOf: bot '${name}' is not defined");
  };
}
