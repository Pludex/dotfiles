{
  modules.home.programs = {
    claude-desktop =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.myPkgs.claude-desktop
        ];
      };

    claude-code = ./claude-code.nix;
    quiz-bot = ./quiz-bot;
  };
}
