{ pkgs, ... }:
{
  programs.obsidian = {
    enable = true;
    package = pkgs.stable.obsidian;
    cli.enable = true;

    defaultSettings = {
      communityPlugins = with pkgs.stable.obsidianPlugins; [
        dataview
        obsidian-git
        obsidian-vimrc-support
      ];

      hotkeys = { };
    };

    vaults.main = {
      enable = true;
      target = "/workspaces/vaults/main";
    };
  };

  stylix.targets.obsidian.enable = true;
}
