{
  pkgs,
  base,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        inherit (base) name;
        email = base.email.main;
      };
      init = {
        defaultBranch = "main";
      };

      # github
      "credential \"https://github.com\"".helper = [
        ""
        "${pkgs.github-cli} auth git-credential"
      ];
      "credential \"https://gist.github.com\"".helper = [
        ""
        "${pkgs.github-cli}/bin/gh auth git-credential"
      ];

      # sign
      gpg.format = "ssh";
      commit.gpgSign = true;

      user.signingKey = "${base.abs.home}/.ssh/id_ed25519.pub";
    };
    inherit (base) ignores;
  };

  programs.delta.enableGitIntegration = true;
}
