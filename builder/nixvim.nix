{
  mkPkgs,
  mkNixvimModules,
  args,
}:
let
  inherit (args) inputs;
in
{
  mk =
    {
      system,
      profile,
      extraNixvimModules ? [ ],
    }:
    let
      pkgs = mkPkgs { inherit system; };
      modules = (mkNixvimModules { inherit extraNixvimModules profile; }) ++ [
        {
          nixpkgs.pkgs = pkgs;
        }
      ];
    in
    inputs.nixvim.lib.evalNixvim {
      inherit modules;
      extraSpecialArgs = args;
    };

  mkPackage =
    {
      profile,
      pkgs,
    }:
    let
      nixvimPkg = inputs.self.nixvimConfigurations.${pkgs.stdenv.system}.${profile}.config.build.package;
    in
    pkgs.stdenv.mkDerivation {
      name = profile;
      buildInputs = [ pkgs.makeWrapper ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.neovide}/bin/neovide $out/bin/${profile}ide \
          --prefix PATH : "${nixvimPkg}/bin"
        ln -s ${nixvimPkg}/bin/nvim $out/bin/${profile}
      '';
    };
}
