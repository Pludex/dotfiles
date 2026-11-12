{ base, pkgs, ... }:
{
  programs.fish = {
    enable = true;

    inherit (base.tools) shellAliases;

    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        name = "done";
        src = pkgs.fishPlugins.done.src;
      }
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
    ];

    shellInitLast = ''
      set fish_greeting ""
    '';

    functions = {
      clear = "command clear -x $argv";
      clear_push = ''
        printf '\e[2J'
        commandline -f repaint
      '';
    };
  };

  xdg.configFile."fish/functions/fish_user_key_bindings.fish".text = ''
    function fish_user_key_bindings
      bind ctrl-space _atuin_bind_up
      bind alt-a complete-and-search
      bind tab accept-autosuggestion
      bind alt-q _fzf_search_directory

      bind ctrl-l clear_push

      bind alt-e undo
      bind alt-r redo
    end
  '';

  stylix.targets.fish.enable = true;

  programs.zoxide.enableFishIntegration = true;
  programs.fzf.enableFishIntegration = true;
  programs.starship.enableFishIntegration = true;
  programs.eza.enableFishIntegration = true;
  programs.direnv.enableFishIntegration = true;
  programs.atuin.enableFishIntegration = true;
  programs.lazygit.enableFishIntegration = true;
  programs.nix-index.enableFishIntegration = true;
  programs.kitty.shellIntegration.enableFishIntegration = true;
  programs.tirith.enableFishIntegration = true;
  programs.nix-your-shell.enableFishIntegration = true;
  programs.ghostty.enableFishIntegration = true;
}
