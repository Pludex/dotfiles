{
  pkgs,
  base,
  config,
  lib,
  ...
}:
let
  app = base.app "hermes-agent";
  guest = app.container.nixosConfig;
  toplevel = guest.config.system.build.toplevel;
  coding = base.group "coding";
  hostuser = app.user "host";
  inherit (app)
    container
    idmap
    age
    network
    ;

  isBridge = network.mode == "bridge";
  isPasta = network.mode == "pasta";
  isUserNs = isBridge || isPasta; # modes that need port publishing
  hostRuntimeDir = "/run/user/${toString hostuser.uid}";
  hostUserUnit = "user@${toString hostuser.uid}.service";
  networkUnit = "podman-network-${network.name}.service";

  mapArg = flag: seg: "--${flag}=${toString seg.inner}:${toString seg.outer}:${toString seg.count}";
  keyPath = config.sops.secrets.${age.sopsSecret}.path;
in
{
  virtualisation.podman.enable = true;

  sops.secrets.${age.sopsSecret} = {
    owner = null;
    uid = app.users.container.uid;
    mode = "0400";
    restartUnits = [ container.unit ];
  };

  users.users.${hostuser.username} = {
    inherit (hostuser) uid home group;
    isSystemUser = true;
    linger = true;
    createHome = true;
    extraGroups = [
      "keys" # of sops-nix
      "coding"
    ];

    autoSubUidGidRange = false;
    subUidRanges = [
      {
        startUid = hostuser.subUid.start;
        count = hostuser.subUid.count;
      }
    ];
    # Order matters: the first range becomes intermediate gid 1 (host coding)
    subGidRanges = [
      {
        startGid = coding.gid;
        count = 1;
      }
      {
        startGid = hostuser.subGid.start;
        count = hostuser.subGid.count;
      }
    ];
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.${container.name} = {
      image = container.image.ref;
      # Nearly empty image: the real system comes from the mounted /nix/store
      imageFile = pkgs.dockerTools.buildImage {
        inherit (container.image) name tag;

        # Lets `podman exec` find binaries without full paths
        config.Env = [
          "PATH=/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
        runAsRoot = ''
          mkdir -p ${age.privateDir} ${container.workspaces} ${container.data}
          touch ${age.privateKeyPath}
          chown ${toString app.uid}:${toString coding.gid} -R ${container.workspaces}
          chown ${toString app.uid}:${toString coding.gid} -R ${container.appDir}
        '';
      };
      cmd = [ "${toplevel}/init" ];
      volumes = [
        "/nix/store:/nix/store:ro"
        "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
        "${app.data}:${container.data}"
        "${keyPath}:${age.privateKeyPath}:ro,Z"
      ];
      ports = lib.optionals isUserNs (
        lib.mapAttrsToList (_: p: "${app.loopback}:${toString p}:${toString p}") app.ports
      );
      extraOptions = [
        "--systemd=always"
        "--security-opt=no-new-privileges"
      ]
      ++ (
        if isBridge then
          [
            "--network=${network.name}"
            "--ip=${network.ip}"
          ]
        else if isPasta then
          [ "--network=pasta:--map-host-loopback=${network.pastaHostLoopback}" ]
        else
          [ "--network=host" ]
      )
      ++ lib.mapAttrsToList (_: mapArg "uidmap") idmap.uid
      ++ lib.mapAttrsToList (_: mapArg "gidmap") idmap.gid;
      podman.user = hostuser.username;
    };
  };

  systemd.services.${container.serviceName} = {
    restartIfChanged = true;
    restartTriggers = [
      toplevel
      keyPath
    ];
    requires = lib.optional isBridge networkUnit;
    after = lib.optional isBridge networkUnit;
  };

  systemd.services."podman-network-${network.name}" = lib.mkIf isBridge {
    wantedBy = [ "multi-user.target" ];
    requires = [ hostUserUnit ];
    after = [ hostUserUnit ];
    path = [ pkgs.podman ];
    environment.XDG_RUNTIME_DIR = hostRuntimeDir;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = hostuser.username;
    };
    script = ''
      podman network exists ${network.name} \
        || podman network create --subnet ${network.subnet} --gateway ${network.gateway} ${network.name}
    '';
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "login-hermes-container" ''
      exec sudo ${pkgs.systemd}/bin/machinectl shell ${hostuser.username}@ \
        ${pkgs.podman}/bin/podman exec -it --user ${app.username} ${container.name} ${lib.getExe base.tools.shell} "$@"
    '')
  ];
}
