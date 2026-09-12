{
  pkgs,
  sources,
  ...
}:

let
  source = sources.msbuild-project-tools-server;
in
pkgs.buildDotnetModule {
  pname = "msbuild-project-tools-server";
  version = "0.7.0";

  src = source;

  dotnetSdk = pkgs.dotnet-sdk;
  dotnetRuntime = pkgs.dotnet-runtime;

  nugetDeps = ./deps.json;

  # Workaround for MSB4018 (GenerateDepsFile IO Exception):
  # Nix store sources are strictly read-only by default. However, .NET MSBuild
  # requires write access to the source tree to create local bin/obj directories
  # and generate dependency files during the restore phase.
  preConfigure = ''
    chmod -R +w .
  '';

  projectFile = "MSBuildProjectTools.sln";

  dotnetBuildFlags = [
    "--no-self-contained"
    # Force single-threaded compilation (-maxcpucount:1) to prevent file-locking
    # race conditions and MSB4018 errors between closely linked sub-projects.
    "-maxcpucount:1"
  ];

  dotnetRestoreFlags = [
    # Disable automated .deps.json file generation during the restore phase
    # to avoid parallel I/O clashes across multi-project solutions.
    "/p:GenerateDependencyFile=false"
  ];

  meta = {
    description = "Language server for MSBuild project files";
    homepage = "https://github.com/tintoy/msbuild-project-tools-server";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
    mainProgram = "MSBuildProjectTools.LanguageServer.Host";
  };
}
