{
  inputs,
  base,
  lib,
  config,
  ...
}:
let
  inherit (config) isContainer bot;
in
{
  config = lib.mkMerge [
    (lib.mkIf (!isContainer) {
      sops = {
        defaultSopsFile = "${base.paths.data}/main.enc.yaml";
        age.keyFile = base.age.privateKeyPath;
      };
    })

    (lib.mkIf isContainer {
      sops = {
        defaultSopsFile = bot.age.defaultFile;
        age.keyFile = bot.age.privateKeyPath;
      };
    })
  ];

  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];
}
