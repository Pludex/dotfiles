{ config, inputs, ... }:
{
  extraBase = rec {
    apps = {
      hermes-agent = rec {
        port = 8642;
        baseUrl = "http://127.0.0.1:${toString port}";
        data = "/workspaces/hermes";

        username = "hermes";
        uid = 2000;
        home = "/home/hermes";

        age = {
          publicKey = "age158va6e0syfx3cm2rwj7un2yu7p8zwqnxdqtedk5tkwk3g7nuxflspzs0em";
          privateKeyPath = "/private/hermes.age-key.txt";
          defaultFile = "${config.paths.data}/hermes.enc.yaml";
        };

        nixosConfigs = {
          container = inputs.self.nixosConfigurations.hermes-agent;
        };

        users.host = {
          username = "hermes-host";
          home = "/var/lib/hermes-host";
          uid = 1002;
        };

        modules.nixos =
          let
            coding = config.base.group "coding";
          in
          {
            users.groups.coding.gid = coding.gid;
            users.users.${username}.extraGroups = [ "coding" ];
            users.users.root.extraGroups = [ "coding" ];
          };

        user = name: (app "hermes-agent").users.${name};
      };

      omniroute = rec {
        port = 20128;
        baseUrl = "http://127.0.0.1:${toString port}";
        data = "/workspaces/omniroute";
      };
    };

    app = name: apps.${name} or (throw "app: '${name}' is not defined");
  };
}
