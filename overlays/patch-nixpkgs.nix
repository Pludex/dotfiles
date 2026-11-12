_: final: prev: {
  # TODO: remove once nixpkgs fixes neocmakelsp (onig_sys needs pkg-config)
  neocmakelsp = prev.neocmakelsp.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.oniguruma ];
  });

  # TODO: remove once speechrecognition tests no longer hit the network
  # (the Nix sandbox has no network access, so test_openai.py fails)
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pyFinal: pyPrev: {
      speechrecognition = pyPrev.speechrecognition.overridePythonAttrs (old: {
        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          "tests/recognizers/whisper_api/test_openai.py"
        ];
      });
    })
  ];

  # TODO: remove once nixpkgs fixes the libgit2 version mismatch in nu_plugin_gstat
  # (libgit2-sys wants libgit2 >= 1.9.6 and < 1.10.0; unset the flag so the crate
  # builds its bundled libgit2 instead)
  nushellPlugins = prev.nushellPlugins // {
    gstat = prev.nushellPlugins.gstat.overrideAttrs (old: {
      env = removeAttrs (old.env or { }) [ "LIBGIT2_NO_VENDOR" ];
      preBuild = (old.preBuild or "") + ''
        unset LIBGIT2_NO_VENDOR
      '';
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        final.pkg-config
        final.cmake
      ];
    });
  };
}
