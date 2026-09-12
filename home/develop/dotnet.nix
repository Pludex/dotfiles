{ pkgs, ... }: {
  home.packages = [
    pkgs.dotnet.sdk
  ];
}
