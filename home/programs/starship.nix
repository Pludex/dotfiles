{ base, pkgs, ... }:
{
  programs.starship = {
    enable = true;

    enableTransience = true;
    settings = {
      add_newline = true;
      # format = "$directory$git_branch$git_status$dotnet$line_break$character";

      character = {
        success_symbol = "${base.glyphs.nix.logo} ${base.glyphs.prompt}";
        error_symbol = "[${base.glyphs.level.error}](bold #ff5555)  ${base.glyphs.prompt}";
      };
    };
  };

  home.packages = [ pkgs.starship ];
  stylix.targets.starship.enable = true;
}
