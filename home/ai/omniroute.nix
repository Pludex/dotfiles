{ config, lib, pkgs, ... }:
let
  pw = pkgs.playwright-driver;
  omnirouteVersion = "3.8.51";

  packageJson = pkgs.writeText "omniroute-package.json" (builtins.toJSON {
    name = "omniroute-host";
    private = true;
    dependencies.omniroute = omnirouteVersion;
    overrides = {
      playwright-core = pw.version;
      playwright = pw.version;
    };
  });

  omniroute = pkgs.writeShellScriptBin "omniroute" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.nodejs_22
        pkgs.coreutils
        pkgs.diffutils
        pkgs.bash
        pkgs.gnumake
        pkgs.gcc
        pkgs.python3
      ]
    }:$PATH
    export PLAYWRIGHT_BROWSERS_PATH=${pw.browsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

    dir="''${XDG_DATA_HOME:-$HOME/.local/share}/omniroute-app"
    mkdir -p "$dir"
    if ! cmp -s ${packageJson} "$dir/package.json"; then
      cp ${packageJson} "$dir/package.json"
      chmod u+w "$dir/package.json"
      (cd "$dir" && npm install --no-audit --no-fund) || { rm -f "$dir/package.json"; exit 1; }
    fi
    exec "$dir/node_modules/.bin/omniroute" "$@"
  '';
in
{
  imports = [ ./modules/omniroute.nix ];

  sops.secrets."api-keys/openrouter/omniroute" = { };

  services.omniroute = {
    enable = true;
    package = omniroute;
    readyTimeout = 300;
    # providers.openrouter.apiKeyFile = config.sops.secrets."api-keys/openrouter/omniroute".path;
    environment = {
      PLAYWRIGHT_BROWSERS_PATH = "${pw.browsers}";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      OMNIROUTE_SERVER_HOST = "127.0.0.1";
    };
  };
}
