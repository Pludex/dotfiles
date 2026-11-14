{
  modules.home.develop = {
    dotnet = { pkgs, ... }: {
      home.packages = [
        pkgs.dotnet.sdk
      ];

      home.sessionVariables = {
        DOTNET_ROOT = "${pkgs.dotnet.sdk}";
      };
    };

    android = { pkgs, ... }: {
      home.packages = [
        pkgs.gnirehtet
        pkgs.android-tools
      ];
    };
  };
}
