{ mkPkgs, args }:
let
  inherit (args) base;
in
{
  mkEmacsPackage =
    { system, ... }:
    let
      pkgs = mkPkgs { inherit system; };
      inherit (pkgs) lib;

      cfg = import "${base.emacs}/default.nix" ({ inherit pkgs; } // args);

      earlyInit = cfg.earlyInit or "";
      extraPackages = cfg.extraPackages or [ ];
      emacsPackage = cfg.package or pkgs.emacs;
      packagesFile = cfg.packagesFile;
      extraEmacsPackages = cfg.extraEmacsPackages or (_: [ ]);

      earlyInitEl = pkgs.writeText "early-init.el" earlyInit;

      configEmacs = pkgs.runCommand "emacs-config" { } ''
        mkdir -p $out
        cp -r ${base.emacs}/. $out/
        chmod -R u+w $out
        cp ${earlyInitEl} $out/early-init.el
      '';

      emacsWithPackages = pkgs.emacsWithPackagesFromUsePackage {
        config = packagesFile;
        alwaysEnsure = true;
        package = emacsPackage;
        inherit extraEmacsPackages;
      };

      emacsWrapped = pkgs.symlinkJoin {
        name = "emacs";
        paths = [ emacsWithPackages ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/emacs \
            --add-flags "--init-directory=\"${configEmacs}\"" \
            --prefix PATH : ${lib.makeBinPath extraPackages}
        '';
      };
    in
    emacsWrapped;
}
