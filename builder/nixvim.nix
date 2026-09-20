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

      modules = mkNixvimModules { inherit extraNixvimModules profile; } ++ [
        # Overlays are baked into mkPkgs, so `args` must not carry its own pkgs.
        { nixpkgs.pkgs = pkgs; }
      ];
    in
    inputs.nixvim.lib.evalNixvim {
      inherit modules;
      extraSpecialArgs = args;
    };

  # Wraps the built nixvim in neovide, so `<profile>ide` starts a GUI with the
  # same config while `<profile>` is the plain terminal nvim.
  mkPackage =
    {
      profile,
      pkgs,
    }:
    let
      nixvimPkg =
        inputs.self.nixvimConfigurations.${pkgs.stdenv.hostPlatform.system}.${profile}.config.build.package;
    in
    pkgs.stdenv.mkDerivation {
      name = profile;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.neovide}/bin/neovide $out/bin/${profile}ide \
          --prefix PATH : "${nixvimPkg}/bin"
        ln -s ${nixvimPkg}/bin/nvim $out/bin/${profile}
      '';
      meta.mainProgram = profile;
    };
}
