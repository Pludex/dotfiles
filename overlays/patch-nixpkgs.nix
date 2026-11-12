_: final: prev: {
  nu_plugin_gstat = prev.nu_plugin_gstat.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.libgit2 ];
  });

  neocmakelsp = prev.neocmakelsp.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ final.oniguruma ];
  });

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pyFinal: pyPrev: {
      speechrecognition = pyPrev.speechrecognition.overridePythonAttrs (old: {
        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          "tests/recognizers/whisper_api/test_openai.py"
        ];
      });
    })
  ];

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

  patchelf = prev.patchelf.overrideAttrs (old: {
    patches = final.lib.filter (
      p: !(final.lib.hasInfix "fix-executable-header-load-overlap" (toString p))
    ) (old.patches or [ ]);
  });

  pnpm = prev.pnpm.overrideAttrs (old: {
    nativeBuildInputs = map (p: if (p.pname or "") == "patchelf" then final.patchelfUnstable else p) (
      old.nativeBuildInputs or [ ]
    );
  });
}
