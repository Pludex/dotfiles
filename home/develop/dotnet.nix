{ pkgs, ... }: {
  home.packages = [
    pkgs.dotnet.sdk
  ];

  home.sessionVariables = {
    DOTNET_ROOT = "${pkgs.dotnet.sdk}";
  };
}
