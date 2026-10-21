{
  hosts.nixos-container = {
    gpus = [ ];
    system = "x86_64-linux";
    modules.nixos = {
      isContainer = true;
    };
  };
}
