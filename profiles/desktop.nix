{
  home =
    { base, ... }:
    let
      a = base.home.apps;
      # r = base.home.root;
      p = base.home.programs;
      s = base.home.services;
      d = base.home.develop;
      i = base.home.ides;
    in
    {
      imports = [
        # "${r}/flatpak"

        "${a}/bitwarden.nix"
        "${a}/claude-desktop.nix"
        "${a}/discord.nix"
        "${a}/obsidian.nix"
        "${a}/sklauncher.nix"
        "${a}/spotify.nix"
        "${a}/steam.nix"
        "${a}/vivaldi.nix"
        "${a}/wps.nix"
        "${a}/zalo.nix"

        "${p}/fastfetch"
        # "${p}/firefox"
        # "${p}/floorp"
        "${p}/nushell"
        "${p}/statix"
        "${p}/wezterm"
        "${p}/zsh"

        "${p}/atuin.nix"
        "${p}/bash.nix"
        "${p}/bat.nix"
        "${p}/btop.nix"
        "${p}/carapace.nix"
        "${p}/delta.nix"
        "${p}/direnv.nix"
        "${p}/emacs.nix"
        "${p}/eza.nix"
        "${p}/fd.nix"
        "${p}/fish.nix"
        "${p}/fzf.nix"
        "${p}/gh.nix"
        "${p}/ghostty.nix"
        "${p}/kitty.nix"
        "${p}/lazygit.nix"
        "${p}/mpv.nix"
        "${p}/nh.nix"
        "${p}/nix-index.nix"
        "${p}/nix-your-shell.nix"
        "${p}/nixvim.nix"
        "${p}/packages.nix"
        "${p}/ripgrep.nix"
        "${p}/starship.nix"
        # "${p}/sunix.nix"
        "${p}/superfile.nix"
        "${p}/tirith.nix"
        "${p}/zoxide.nix"

        "${s}/audio-manager"
        # "${s}/espanso.nix"

        "${d}/dotnet.nix"

        "${i}/vscode.nix"
        "${i}/rider.nix"
      ];
    };

  nixos =
    { base, ... }:
    let
      s = base.nixos.services;
      v = base.nixos.virtualisation;
    in
    {
      imports = [
        # "${s}/caddy.nix"
        "${s}/envfs.nix"
        # "${s}/flatpak.nix"
        # "${s}/nginx.nix"
        "${s}/ngrok.nix"
        "${s}/vaultwarden.nix"

        "${v}/core/libvirt.nix"
        "${v}/win10.nix"
      ];
    };
}
