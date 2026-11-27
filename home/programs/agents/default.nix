{
  modules.home.programs = {
    claude-desktop =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.myPkgs.claude-desktop
        ];
      };

    claude-code = ./claude-code;
    quiz-bot = ./quiz-bot;
  };
}
