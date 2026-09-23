_:
(final: prev: {

  neovide = prev.symlinkJoin {
    name = "neovide-wrapped";
    paths = [ prev.neovide ];
    postBuild = ''
      rm $out/bin/neovide
      ln -s ${prev.writeShellScript "neovide-bg" ''
        setsid ${prev.neovide}/bin/neovide &
      ''} $out/bin/neovide
    '';
  };
})
