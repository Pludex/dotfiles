{ base, ... }:
{
  programs.starship = {
    enable = true;
    enableTransience = true;

    settings = {
      add_newline = true;

      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";

      character = {
        success_symbol = "[${base.glyphs.nix.logo}](bold blue) [${base.glyphs.prompt}](bold green)";
        error_symbol = "[${base.glyphs.level.error}](bold red) [${base.glyphs.prompt}](bold red)";
      };

      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncation_symbol = "…/";
        read_only = " 󰌾";
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold yellow";
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "=";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        untracked = "?";
        stashed = "$";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol]($style)";
        style = "bold cyan";
      };

      cmd_duration = {
        min_time = 2000;
        style = "yellow";
        format = "[󰔛 $duration]($style) ";
      };
    };
  };

  stylix.targets.starship.enable = true;
}
