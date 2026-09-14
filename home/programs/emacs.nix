{ inputs, base, ... }:
{
  imports = [
    inputs.doom-emacs.homeModule
    base.emacs
  ];

  programs.doom-emacs = {
    enable = true;
  };
}
