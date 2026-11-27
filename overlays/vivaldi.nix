{ base, ... }: final: prev: {
  vivaldi =
    let
      original = prev.vivaldi;
      mkLauncher =
        name: profile:
        prev.writeShellScriptBin name ''
          exec ${prev.lib.getExe original} --profile-directory="${profile}" "$@"
        '';

      inherit (base.vivaldi) profiles;
    in
    prev.symlinkJoin {
      name = "vivaldi-${original.version}";
      paths = [
        original
        (mkLauncher "vivaldi-work" profiles.work.nameDir)
        (mkLauncher "vivaldi-society" profiles.society.nameDir)
      ];
      meta = original.meta // {
        mainProgram = "vivaldi";
      };
    };
}
