{ base, lib, ... }:
let
  hp = base.paths.home;
  np = base.paths.nixos;
  vp = base.paths.nixvim;

  # Registers every `<name>.nix` file and `<name>/` directory under `dir` as `<name>`.
  fromDir =
    dir:
    lib.optionalAttrs (builtins.pathExists dir) (
      lib.mapAttrs' (n: _: lib.nameValuePair (lib.removeSuffix ".nix" n) (dir + "/${n}")) (
        lib.filterAttrs (n: t: n != "default.nix" && (t == "directory" || lib.hasSuffix ".nix" n)) (
          builtins.readDir dir
        )
      )
    );

  homeCatalogs = lib.genAttrs [
    "apps"
    "programs"
    "services"
    "develop"
  ] (c: fromDir hp.${c});
in
{
  imports = [
    ./ci.nix
    ./coding.nix
    ./desktop.nix
    ./leetcode.nix
    ./live.nix
  ];

  modules = {
    home = homeCatalogs;
    rootHome = homeCatalogs;

    nixos = lib.genAttrs [
      "services"
      "virtualisation"
      "apps"
    ] (c: fromDir np.${c});

    nixvim = lib.genAttrs [
      "languages"
      "root"
    ] (c: fromDir vp.${c});
  };
}
