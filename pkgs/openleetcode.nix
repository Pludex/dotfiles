{
  lib,
  stdenvNoCC,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
  runtimeShell,
  python3,
  cmake,
  gnumake,
  gcc,
  electron,
  inputs,
  withUI ? true,
}:

let
  src = inputs.openleetcode;
  version = src.shortRev or src.dirtyShortRev or "unknown";
  python = python3.withPackages (ps: [ ps.jsonschema ]);

  ui = buildNpmPackage {
    pname = "openleetcode-ui";
    inherit version;

    src = "${src}/src/ui";

    npmDeps = importNpmLock { npmRoot = "${src}/src/ui"; };
    npmConfigHook = importNpmLock.npmConfigHook;

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      app=$out/lib/openleetcode-ui
      mkdir -p $app
      cp -r . $app
      rm -rf $app/node_modules/electron $app/node_modules/electron-packager $app/node_modules/.bin
      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "openleetcode";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    share=$out/share/openleetcode
    mkdir -p $share/app $out/bin

    cp -r data $share/data
    cp src/app/*.py $share/app/
    cp src/schema/results_validation_schema.json $share/app/

    # The problems tree is mutated at runtime (solutions, cmake build dirs),
    # so it is seeded into a writable per-user directory instead of the store.
    # openleetcode.sh is linked there because the UI invokes the CLI from it.
    cat > $share/seed.sh <<'EOF'
    data_dir="''${OPENLEETCODE_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/openleetcode}"
    mkdir -p "$data_dir"
    cp -r --update=none --no-preserve=mode,ownership @share@/data/. "$data_dir"/
    cp -f --no-preserve=mode,ownership @share@/app/results_validation_schema.json "$data_dir"/
    ln -sfn @out@/bin/openleetcode "$data_dir/openleetcode.sh"
    EOF

    cat > $out/bin/openleetcode <<'EOF'
    #!@runtimeShell@
    . @share@/seed.sh
    exec @python@/bin/python @share@/app/openleetcode.py \
      --problem_builds_dir "$data_dir" "$@"
    EOF
    chmod +x $out/bin/openleetcode

    substituteInPlace $share/seed.sh $out/bin/openleetcode \
      --subst-var-by runtimeShell ${runtimeShell} \
      --subst-var-by python ${python} \
      --subst-var-by share $share \
      --subst-var-by out $out

    wrapProgram $out/bin/openleetcode \
      --prefix PATH : ${
        lib.makeBinPath [
          cmake
          gnumake
          gcc
        ]
      }
  ''
  + lib.optionalString withUI ''
    # The UI writes filePaths.tmp and testcase_output into its cwd.
    cat > $out/bin/openleetcode-ui <<'EOF'
    #!@runtimeShell@
    . @share@/seed.sh
    cd "$data_dir"
    exec @electron@/bin/electron @ui@/lib/openleetcode-ui \
      --problem_builds_dir="$data_dir" "$@"
    EOF
    chmod +x $out/bin/openleetcode-ui

    substituteInPlace $out/bin/openleetcode-ui \
      --subst-var-by runtimeShell ${runtimeShell} \
      --subst-var-by share $share \
      --subst-var-by electron ${electron} \
      --subst-var-by ui ${ui}
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Offline, local LeetCode-style problem runner for C++ and Python";
    homepage = "https://github.com/mbucko/openleetcode";
    license = lib.licenses.mit;
    mainProgram = "openleetcode";
    platforms = lib.platforms.unix;
  };
}
