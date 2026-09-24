{
  extraBaseWithPkgs =
    pkgs:
    let
      inherit (pkgs) lib;
    in
    {
      tools = rec {
        vivaldi = {
          cmdProfileWork = ''${lib.getExe pkgs.vivaldi} --profile-directory="Default" &'';
          cmdProfileSociety = ''${lib.getExe pkgs.vivladi} --profile-directory "Profile 1" &'';
        };

        shell = pkgs.fish;
        editor = pkgs.myPkgs.ecode;
        browser = pkgs.vivaldi;
        # pager = "bat --plain --pager='less -FR'";
        pager = pkgs.bat;
        term = pkgs.ghossty;

        shellAliases = {
          cd = "z";
          cat = "bat";
          less = lib.getExe pager;
          nano = lib.getExe editor;
          grep = "rg";
          find = "fd";
          tree = "eza -T";
        };

        envvars = {
          EDITOR = "${lib.getExe editor}";
          BROWSER = vivaldi.cmdProfileWork;
        };
      };
    };
}
