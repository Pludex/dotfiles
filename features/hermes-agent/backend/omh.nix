{
  config,
  lib,
  pkgs,
  ...
}:
let
  h = import ./lib.nix { inherit config lib pkgs; };
  inherit (h)
    cfg
    omhHome
    hermesHomes
    profileUnits
    ;
  omhPkg = cfg.omh.package;

  # Used only as a fallback when /v1/models is unreachable and as a sanity check
  combos = lib.unique (lib.concatMap (map (s: s.model)) (lib.attrValues cfg.omh.chains));

  chainsFile = pkgs.writeText "model-chains.json" (
    builtins.toJSON {
      schema_version = "mixture_chain_overrides/v1";
      categories = lib.mapAttrs (
        _: map (s: {
          inherit (s) model;
          reasoning_effort = s.reasoningEffort;
        })
      ) cfg.omh.chains;
    }
  );

  routesFile = pkgs.writeText "model-providers.json" (
    builtins.toJSON {
      schema_version = "model_provider_routes/v1";
      models = lib.genAttrs combos (model: {
        provider = "custom:omniroute";
        inherit model;
      });
    }
  );

  omhSync = pkgs.writeShellScript "omh-sync" ''
    set -euo pipefail
    export OMH_HOME=${omhHome}
    mkdir -p "$OMH_HOME/routing"

    # OMH_HOME is shared, but the plugin is installed per HERMES_HOME.
    for target in ${lib.escapeShellArgs hermesHomes}; do
      mkdir -p "$target"
      if [ "$(cat "$target/.omh-nix-store-path" 2>/dev/null || true)" != "${omhPkg}" ]; then
        HERMES_HOME="$target" omh setup --no-interactive --json
        printf '%s' "${omhPkg}" > "$target/.omh-nix-store-path"
      fi
    done

    install -m 0644 ${chainsFile} "$OMH_HOME/routing/model-chains.json"

    # model-providers.json: generated from omniroute's /v1/models at runtime.
    dst="$OMH_HOME/routing/model-providers.json"
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT

    if curl -fsS --max-time 10 \
         -H "Authorization: Bearer $OMNIROUTE_API_KEY" \
         "${cfg.omniroute.baseUrl}/v1/models" \
       | jq '{
           schema_version: "model_provider_routes/v1",
           models: (
             .data
             | map({
                 key: .id,
                 value: { provider: "custom:omniroute", model: .id }
               })
             | from_entries
           )
         }' > "$tmp" \
       && [ "$(jq '.models | length' "$tmp")" -gt 0 ]; then
      install -m 0644 "$tmp" "$dst"

      jq -r --argjson want '${builtins.toJSON combos}' \
        '($want - (.models | keys))[]' "$dst" \
        | while read -r m; do
            echo "warning: chain model '$m' not found in omniroute /v1/models" >&2
          done
    else
      echo "omniroute /v1/models unavailable, keeping existing routes or using fallback" >&2
      [ -f "$dst" ] || install -m 0644 ${routesFile} "$dst"
    fi
  '';

  themeSync = pkgs.writeShellScript "hermes-theme-pack" ''
    set -euo pipefail

    for target in ${lib.escapeShellArgs hermesHomes}; do
      mkdir -p "$target/skins" "$target/plugins"

      # Overwrite the pack's skins, keep any skin the user added by hand.
      install -m 0644 ${cfg.themePack.src}/themes/*.yaml "$target/skins/"

      # Replaced wholesale so updates and removals propagate.
      rm -rf "$target/plugins/theme-switcher"
      cp -R --no-preserve=mode,ownership \
        ${cfg.themePack.src}/plugins/theme-switcher "$target/plugins/theme-switcher"

      HERMES_HOME="$target" hermes plugins enable theme-switcher
    done
  '';
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.omh.enable {
        home.packages = [ omhPkg ];

        systemd.user.services.omh-sync = {
          Unit = {
            Description = "Sync oh-my-hermes into the hermes home and profiles";
            After = [
              "sops-nix.service"
              "podman-omniroute.service"
              "omniroute-bootstrap.service"
              "hermes-env-merge.service"
            ]
            ++ lib.optional cfg.themePack.enable "hermes-theme-pack.service"
            ++ profileUnits;
            Wants = [
              "sops-nix.service"
              "hermes-env-merge.service"
            ]
            ++ lib.optional cfg.themePack.enable "hermes-theme-pack.service"
            ++ profileUnits;
            PartOf = profileUnits;
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${omhSync}";
            # provides OMNIROUTE_API_KEY for the /v1/models request
            EnvironmentFile = [ (h.templatePath "hermes-env") ];
            Environment = [
              "PATH=${
                lib.makeBinPath [
                  pkgs.coreutils
                  pkgs.curl
                  pkgs.jq
                  omhPkg
                ]
              }:${config.home.profileDirectory}/bin"
            ];
          };
        };

        # Refresh the model list so new omniroute combos show up without a rebuild.
        systemd.user.timers.omh-sync = {
          Unit.Description = "Periodic oh-my-hermes / omniroute model sync";
          Timer = {
            OnBootSec = "1min";
            OnUnitActiveSec = cfg.omh.syncInterval;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      })

      (lib.mkIf cfg.themePack.enable {
        # Re-runs whenever a profile is re-provisioned (PartOf), since that
        # overwrites config.yaml and drops the plugin enablement.
        systemd.user.services.hermes-theme-pack = {
          Unit = {
            Description = "Install Hermes theme pack skins and Theme Switcher plugin";
            After = [
              "sops-nix.service"
              "hermes-env-merge.service"
            ]
            ++ profileUnits;
            Wants = profileUnits;
            PartOf = profileUnits;
            Before = [
              "hermes-agent.service"
              "hermes-backend.service"
            ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${themeSync}";
            Environment = [
              "PATH=${lib.makeBinPath [ pkgs.coreutils cfg.package ]}"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
