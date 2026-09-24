{ base, ... }:
{
  programs.bash = {
    enable = true;
    inherit (base.tools) shellAliases;
  };

  programs.zoxide.enableBashIntegration = true;
  programs.fzf.enableBashIntegration = true;
  programs.starship.enableBashIntegration = true;
  programs.eza.enableBashIntegration = true;
  programs.direnv.enableBashIntegration = true;
  programs.atuin.enableBashIntegration = true;
  programs.lazygit.enableBashIntegration = true;
  programs.nix-index.enableBashIntegration = true;
  programs.kitty.shellIntegration.enableBashIntegration = true;
  programs.tirith.enableBashIntegration = true;

}
