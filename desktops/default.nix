{ desktop }: {
  nixos = ./${desktop}/nixos;
  home = ./${desktop}/home;
}
