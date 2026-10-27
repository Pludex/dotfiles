{
  inputs,
  base,
  lib,
  config,
  ...
}:
let
  inherit (config) isContainer app;
in
{
  config = lib.mkMerge [
    (lib.mkIf (!isContainer) {
      sops = {
        defaultSopsFile = base.age.defaultFile;
        age.keyFile = base.age.privateKeyPath;
      };
    })

    (lib.mkIf isContainer {
      sops = {
        defaultSopsFile = app.age.defaultFile;
        age.keyFile = app.age.privateKeyPath;
      };
    })
  ];

  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];
}
