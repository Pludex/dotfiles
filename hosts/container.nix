{
  hosts.nixos-container = {
    system = "x86_64-linux";
    modules.nixos = {
      isContainer = true;
      boot.isContainer = true;
    };
  };

  hosts.container = {
    system = "x86_64-linux";
    modules.nixos = {
      isContainer = true;
    };
  };
}
