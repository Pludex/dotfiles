{
  config,
  lib,
  pkgs,
  inputs,
  base,
  ...
}:
let
  src = inputs.omniroute;
  podman = config.services.podman.package;
  srcId = builtins.substring 0 12 (baseNameOf (toString src));
  data = base.groupOf "data";

  bootstrap = pkgs.writeShellScript "omniroute-bootstrap" ''
    set -euo pipefail
    tag=localhost/omniroute:src-${srcId}
    rebuilt=0

    if ! podman image exists "$tag"; then
      podman build --target runner-web -t "$tag" -f ${src}/Dockerfile ${src}
      rebuilt=1
    fi
    podman tag "$tag" localhost/omniroute:web

    if [ "$rebuilt" = 1 ]; then
      systemctl --user restart --no-block podman-omniroute.service
      podman images --format '{{.Repository}}:{{.Tag}}' \
        | grep '^localhost/omniroute:src-' | grep -vx "$tag" \
        | xargs -r podman rmi || true
    else
      systemctl --user start --no-block podman-omniroute.service
    fi
  '';

  app = base.appOf "omniroute";
in
{
  config = {
    sops.secrets."api-keys/openrouter/omniroute" = { };

    sops.templates."omniroute.env".content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder."api-keys/openrouter/omniroute"}
    '';

    services.podman = {
      enable = true;

      containers.omniroute = {
        image = "localhost/omniroute:web";
        autoStart = false;
        network = "host";
        userNS = "keep-id";
        extraPodmanArgs = [ "--user=${toString base.uid}:${toString data.gid}" ];
        environment = {
          PORT = toString app.port;
          HOSTNAME = "localhost";
          DATA_DIR = "/app/data";
        };
        environmentFile = [ config.sops.templates."omniroute.env".path ];
        volumes = [ "${app.abs.data}:/app/data" ];
        extraConfig = {
          Unit = {
            After = [ "sops-nix.service" ];
            Wants = [ "sops-nix.service" ];
          };
          Container.StopTimeout = 40;
          Service.Restart = "on-failure";
        };
      };
    };

    systemd.user.services.omniroute-bootstrap = {
      Unit = {
        Description = "Build the OmniRoute image and start its container";
        After = [ "sops-nix.service" ];
      };
      Service = {
        Type = "simple";
        # The native module build (node-gyp) takes minutes; never time it out.
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "infinity";
        Nice = 10;
        Environment = [
          "PATH=${
            lib.makeBinPath [
              podman
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.findutils
              pkgs.systemd
            ]
          }:/run/wrappers/bin"
        ];
        ExecStart = bootstrap;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
