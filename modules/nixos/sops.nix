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
        defaultSopsFile = base.age.defaultFile;
        age.keyFile = base.age.privateKeyPath;
        useSystemdActivation = true;
      };
    })

    (lib.mkIf isContainer {
      sops = {
        defaultSopsFile = bot.age.defaultFile;
        age.keyFile = base.age.privateKeyPath;
        useSystemdActivation = true;
      };
    })
  ];

  imports = with inputs; [
    sops-nix.nixosModules.sops
  ];
}
