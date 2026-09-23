{
  pkgs,
  config,
  base,
  ...
}:
{
  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      share = true;
    };

    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.8.0";
          sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
        };
      }
    ];

    shellAliases = base.tools.alias;

    dotDir = "${config.xdg.configHome}/zsh";

    oh-my-zsh = import ./oh-my-zsh;
    initContent = builtins.readFile ./init.zsh;
  };

  programs.zoxide.enableZshIntegration = true;
  programs.fzf.enableZshIntegration = true;
  programs.starship.enableZshIntegration = true;
  programs.eza.enableZshIntegration = true;
  programs.direnv.enableZshIntegration = true;
  programs.atuin.enableZshIntegration = true;
  programs.lazygit.enableZshIntegration = true;
  programs.nix-index.enableZshIntegration = true;
  programs.kitty.shellIntegration.enableZshIntegration = true;
  programs.tirith.enableZshIntegration = true;
}
