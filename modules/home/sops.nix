{
  base,
  inputs,
  ...
}:
{
  sops = {
    age.keyFile = base.age.privateKeyPath;
    defaultSopsFile = "${base.paths.data}/main.enc.yaml";
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];
}
