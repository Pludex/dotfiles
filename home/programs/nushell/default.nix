{ pkgs, ... }:
{
  programs.nushell = {
    enable = true;

    settings = {
      show_banner = false;

      cursor_shape = {
        vi_insert = "line";
        vi_normal = "block";
        emacs = "line";
      };

      completions = {
        external = {
          enable = true;
          max_results = 200;
        };
      };
    };

    plugins = with pkgs.nushellPlugins; [
      query
      formats
      gstat

      highlight
    ];

    extraConfig = ''
      source ${./carbonfox.theme.nu}
    '';
  };

  stylix.targets.nushell.enable = false;

  programs.zoxide.enableNushellIntegration = true;
  programs.fzf.enableNushellIntegration = true;
  programs.starship.enableNushellIntegration = true;
  # programs.eza.enableNushellIntegration = true;
  programs.direnv.enableNushellIntegration = true;
  programs.atuin.enableNushellIntegration = true;
  programs.lazygit.enableNushellIntegration = true;
  programs.nix-index.enableNushellIntegration = true;
  programs.nix-your-shell.enableNushellIntegration = true;
  programs.carapace.enableNushellIntegration = true;
}
