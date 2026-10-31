{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  inherit (h) cfg syncUnits;

  yamlFormat = pkgs.formats.yaml { };

  profileConfig =
    name: p:
    let
      mcp = h.mcpToYaml (h.effectiveMcp p);
    in
    yamlFormat.generate "hermes-${name}-config.yaml" (
      lib.recursiveUpdate (h.settingsOf p) (lib.optionalAttrs (mcp != { }) { mcp_servers = mcp; })
    );

  mkProfileService =
    name: p:
    let
      dir = h.profileDir name;
      setup = pkgs.writeShellScript "hermes-profile-${name}" ''
        set -euo pipefail
        mkdir -p ${dir}
        install -m 0644 ${profileConfig name p} ${dir}/config.yaml
        ${h.mkMergeEnv (h.templatePath "hermes-env-${name}") "${dir}/.env"}

        # config.yaml was just overwritten, so omh must be set up again
        rm -f ${dir}/.omh-nix-store-path
      '';
    in
    {
      Unit = {
        Description = "Provision Hermes profile ${name}";
        After = [ "sops-nix.service" ];
        Wants = [ "sops-nix.service" ];
        Before = [
          "hermes-agent.service"
          "hermes-backend.service"
        ]
        ++ syncUnits;
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${setup}";
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep ]}"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };
in
{
  config = lib.mkIf cfg.enable {
    sops.templates = lib.mapAttrs' (
      n: p: lib.nameValuePair "hermes-env-${n}" { content = h.renderEnv p; }
    ) h.profiles;

    systemd.user.services = lib.mapAttrs' (
      n: p: lib.nameValuePair "hermes-profile-${n}" (mkProfileService n p)
    ) h.profiles;
  };
}
