{
  modules = {
    home.commons = [ ./home ];
    nixos.commons = [ ./nixos ];
  };

  imports = [
    ./nixvim
  ];
}
