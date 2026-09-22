{
  base,
  inputs,
  ...
}:
{
  sops = {
    defaultSopsFile = "${base.paths.data}/main.enc.yaml";
    age.keyFile = base.age.privateKeyPath;
  };

  imports = with inputs; [
    sops-nix.homeManagerModules.sops
  ];

}
