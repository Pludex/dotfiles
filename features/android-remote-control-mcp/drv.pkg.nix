{
  lib,
  stdenv,
  gradle,
  androidenv,
  android-tools,
  inputs,
  flavor ? "gms",
}:

let
  androidComposition = androidenv.composeAndroidPackages {
    platformVersions = [ "35" ];
    buildToolsVersions = [ "35.0.0" ];
  };
  sdkRoot = "${androidComposition.androidsdk}/libexec/android-sdk";

  src = inputs.android-remote-control-mcp;

  gradleTask =
    {
      gms = "assembleGmsDebug";
      foss = "assembleFossDebug";
    }
    .${flavor};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "android-remote-control-mcp";
  version = src.shortRev or "unstable";
  inherit src;

  nativeBuildInputs = [ gradle ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./android-remote-control-mcp-deps.json;
  };

  gradleBuildTask = gradleTask;
  gradleFlags = [
    "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdkRoot}/build-tools/35.0.0/aapt2"
  ];

  ANDROID_HOME = sdkRoot;
  ANDROID_SDK_ROOT = sdkRoot;

  doCheck = false;

  installPhase = ''
    runHook preInstall

    apk=$(find . -path '*/build/outputs/apk/*' -name '*.apk' | head -n1)
    install -Dm444 "$apk" $out/share/android-remote-control-mcp/app.apk

    mkdir -p $out/bin
    cat > $out/bin/android-remote-control-mcp-install <<EOF
    #!${stdenv.shell}
    exec ${android-tools}/bin/adb "\$@" install -r $out/share/android-remote-control-mcp/app.apk
    EOF
    chmod +x $out/bin/android-remote-control-mcp-install

    runHook postInstall
  '';

  meta = {
    description = "MCP server running on Android, controlling the device via accessibility services";
    homepage = "https://github.com/danielealbano/android-remote-control-mcp";
    license = lib.licenses.mit;
    mainProgram = "android-remote-control-mcp-install";
  };
})
