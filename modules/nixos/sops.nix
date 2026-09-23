{
  inputs,
  base,
  ...
}:
{
  sops = {
    defaultSopsFile = "${base.paths.data}/main.enc.yaml";
    age.keyFile = base.age.privateKeyPath;

    secrets."hashedPassword" = { };
  };

  imports = with inputs; [
    sops-nix.nixosModules.sops
  ];
}
