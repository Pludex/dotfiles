{
  modules.home.packages = {
    nix-dev =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nixd
          treefmt
        ];
      };

    utils =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          jq
          file
          sops
        ];
      };

    desktop =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          libnotify
          wifitui
          myPkgs.clipboard
        ];
      };
  };
}
