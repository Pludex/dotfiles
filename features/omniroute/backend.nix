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
  srcId = builtins.substring 0 12 (baseNameOf (toString src));
  podman = config.services.podman.package;
  data = base.group "data";
  app = base.app "omniroute";
  inherit (app) container;

  # Chromium ships under /home/node, which the container user cannot read
  overlay = pkgs.writeText "omniroute-overlay.Containerfile" ''
    FROM ${container.image.repo}:src-${srcId}
    USER root
    RUN mv /home/node/.cache/ms-playwright /opt/ms-playwright \
     && chmod -R a+rX /opt/ms-playwright
    ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
    USER node
  '';

  bootstrap = pkgs.writeShellScript "omniroute-bootstrap" ''
    set -euo pipefail
    base=${container.image.repo}:src-${srcId}
    tag=$base-pw
    rebuilt=0

    if ! podman image exists "$tag"; then
      podman image exists "$base" \
        || podman build --target runner-web -t "$base" -f ${src}/Dockerfile ${src}
      podman build -t "$tag" -f ${overlay} ${pkgs.emptyDirectory}
      rebuilt=1
    fi
    podman tag "$tag" ${container.image.ref}

    if [ "$rebuilt" = 1 ]; then
      systemctl --user restart --no-block ${container.unit}
      podman images --format '{{.Repository}}:{{.Tag}}' \
        | grep '^${container.image.repo}:src-' | grep -vx "$tag" | grep -vx "$base" \
        | sort -r | xargs -r podman rmi || true
    else
      systemctl --user start --no-block ${container.unit}
    fi
  '';
in
{
  sops.secrets."api-keys/openrouter/omniroute" = { };

  sops.templates."omniroute.env".content = ''
    OPENROUTER_API_KEY=${config.sops.placeholder."api-keys/openrouter/omniroute"}
  '';

  services.podman = {
    enable = true;

    containers.${container.name} = {
      image = container.image.ref;
      autoStart = false;
      network = "host";
      userNS = "keep-id";
      extraPodmanArgs = [
        "--user=${toString base.uid}:${toString data.gid}"
        "--shm-size=1g"
      ];
      environment = {
        PORT = toString app.port;
        HOSTNAME = app.listenHost;
        DATA_DIR = container.data;
      };
      environmentFile = [ config.sops.templates."omniroute.env".path ];
      volumes = [ "${app.data}:${container.data}" ];
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
}
