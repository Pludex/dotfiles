{
  inputs,
  base,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (!config.isContainer) {
    sops = {
      defaultSopsFile = "${base.paths.data}/main.enc.yaml";
      age.keyFile = base.age.privateKeyPath;
    };
  };

  imports = with inputs; [
    sops-nix.nixosModules.sops
  ];
}
