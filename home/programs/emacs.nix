{ inputs, base, ... }:
{
  imports = [
    inputs.doom-emacs.homeModule
    base.paths.emacs
  ];

  programs.doom-emacs = {
    enable = true;
  };
}
