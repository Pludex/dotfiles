{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.omniroute;
  esc = lib.escapeShellArg;

  providerModule =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Register this provider.";
        };
        provider = mkOption {
          type = types.str;
          default = name;
          description = "Provider id from `omniroute providers available`.";
        };
        apiKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File holding the provider API key. Leave null for keyless providers.";
        };
        test = mkOption {
          type = types.bool;
          default = true;
          description = "Test the connection right after registering.";
        };
      };
    };

  enabledProviders = lib.filterAttrs (_: p: p.enable) cfg.providers;

  registerProvider = _: p: ''
    if omniroute providers list | grep -qiF ${esc p.provider}; then
      echo "provider ${p.provider} already registered"
    else
      omniroute setup --non-interactive --add-provider --provider ${esc p.provider} \
        ${lib.optionalString p.test "--test-provider"} \
        ${lib.optionalString (p.apiKeyFile != null) ''--api-key "$(cat ${esc p.apiKeyFile})"''} \
        || failed=1
    fi
  '';

  providersScript = pkgs.writeShellScript "omniroute-providers" ''
    failed=0

    for _ in $(seq ${toString cfg.readyTimeout}); do
      curl -s -o /dev/null http://localhost:${toString cfg.port} && break
      sleep 1
    done

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList registerProvider enabledProviders)}

    exit $failed
  '';

  envList = lib.mapAttrsToList (n: v: "${n}=${v}") ({ PORT = toString cfg.port; } // cfg.environment);
in
{
  options.services.omniroute = {
    enable = mkEnableOption "OmniRoute AI gateway";

    version = mkOption {
      type = types.str;
      default = "latest";
      description = "npm version or tag of omniroute run through npx.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.writeShellScriptBin "omniroute" ''
        export PATH=${
          lib.makeBinPath (
            [
              pkgs.nodejs_22
              pkgs.coreutils
              pkgs.bash
            ]
            ++ cfg.extraPackages
          )
        }:$PATH
        exec ${lib.getExe' pkgs.nodejs_22 "npx"} -y omniroute@${cfg.version} "$@"
      '';
      defaultText = lib.literalExpression "npx wrapper around omniroute@version";
      description = "Package providing the `omniroute` binary.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages on PATH for the default wrapper, e.g. build tools for native modules.";
    };

    port = mkOption {
      type = types.port;
      default = 20128;
      description = "Port for both the API and the dashboard.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables for the service.";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Environment files for secrets, passed to systemd as EnvironmentFile.";
    };

    providers = mkOption {
      type = types.attrsOf (types.submodule providerModule);
      default = { };
      description = "Providers registered once after the gateway is up. Already registered ones are skipped.";
    };

    readyTimeout = mkOption {
      type = types.ints.positive;
      default = 60;
      description = "Seconds to wait for the gateway before registering providers.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.omniroute = {
      Unit = {
        Description = "OmniRoute AI gateway";
        After = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/omniroute serve";
        Environment = envList;
        EnvironmentFile = cfg.environmentFiles;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.omniroute-providers = mkIf (enabledProviders != { }) {
      Unit = {
        Description = "Register OmniRoute providers";
        After = [ "omniroute.service" ];
        Requires = [ "omniroute.service" ];
        PartOf = [ "omniroute.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "PATH=${
            lib.makeBinPath [
              cfg.package
              pkgs.curl
              pkgs.gnugrep
              pkgs.coreutils
            ]
          }"
        ];
        ExecStart = providersScript;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
