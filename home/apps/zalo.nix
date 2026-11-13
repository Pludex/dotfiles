{ inputs, ... }:
{
  imports = [ inputs.zalo-for-linux.homeManagerModules.default ];

  programs.zalo = {
    enable = true;
  };
}
