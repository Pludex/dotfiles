{ base, ... }:
{
  programs.nh = {
    enable = true;

    flake = "${base.abs.dotfiles}";
  };
  home.sessionVariables = {
    NH_HOME_FLAKE = "${base.abs.dotfiles}";
  };
}
