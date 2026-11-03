{
  config,
  lib,
  pkgs,
  base,
}:
let
  cfg = config.services.hermes-agent-backend;
  app = base.app "hermes-agent";
  ph = config.sops.placeholder;

  profiles = lib.filterAttrs (_: p: p.enable) cfg.profiles;
  omhHome = "${cfg.hermesHome}/omh";

  profileDir = name: "${cfg.hermesHome}/profiles/${name}";
  profileUnits = map (n: "hermes-profile-${n}.service") (lib.attrNames profiles);
  hermesHomes = [ cfg.hermesHome ] ++ map profileDir (lib.attrNames profiles);

  inherit (app) units;
  coreUnits = map (n: "${n}.service") (lib.attrValues units);

  syncUnits =
    lib.optional cfg.omh.enable "omh-sync.service"
    ++ lib.optional cfg.themePack.enable "hermes-theme-pack.service";

  effectiveMcp =
    inst: lib.filterAttrs (n: s: s.enable && !(lib.elem n inst.excludeMcp)) (cfg.mcp // inst.mcp);

  mcpToYaml = lib.mapAttrs (
    _: s: { inherit (s) url; } // lib.optionalAttrs (s.headers != { }) { inherit (s) headers; }
  );

  secretEnvOf =
    inst:
    lib.foldl' (acc: s: acc // s.secretEnv) { } (lib.attrValues (effectiveMcp inst))
    // inst.secretEnv
    // {
      OPENAI_API_KEY = inst.apiKeySecret;
      OMNIROUTE_API_KEY = inst.apiKeySecret;
    }
    // lib.optionalAttrs (inst.discord.tokenSecret != null) (
      {
        DISCORD_BOT_TOKEN = inst.discord.tokenSecret;
      }
      // lib.optionalAttrs (cfg.allowedUsersSecret != null) {
        DISCORD_ALLOWED_USERS = cfg.allowedUsersSecret;
      }
    );

  plainEnvOf =
    inst:
    let
      d = inst.discord;
    in
    inst.env
    // lib.optionalAttrs cfg.omh.enable { OMH_HOME = omhHome; }
    // lib.optionalAttrs (d.homeChannel != null) {
      DISCORD_HOME_CHANNEL = d.homeChannel;
      DISCORD_HOME_CHANNEL_NAME = d.homeChannelName;
      DISCORD_FREE_RESPONSE_CHANNELS = lib.concatStringsSep "," d.freeChannels;
    };

  renderEnv =
    inst:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (k: s: "${k}=${ph.${s}}") (secretEnvOf inst)
      ++ lib.mapAttrsToList (k: v: "${k}=${v}") (plainEnvOf inst)
    )
    + "\n";

  allSecrets = lib.unique (
    [ cfg.sessionTokenSecret ]
    ++ lib.concatMap (inst: lib.attrValues (secretEnvOf inst)) ([ cfg.main ] ++ lib.attrValues profiles)
  );

  pluginsEnabled =
    lib.optional cfg.omh.enable "omh" ++ lib.optional cfg.themePack.enable "theme-switcher";

  # config.yaml content without MCP servers
  settingsOf =
    inst:
    lib.foldl' lib.recursiveUpdate { } [
      {
        model = {
          provider = "custom:omniroute";
          default = inst.model;
          base_url = "${cfg.omniroute.baseUrl}/v1";
        };
        providers.omniroute = {
          api = "${cfg.omniroute.baseUrl}/v1";
          api_key = "\${OMNIROUTE_API_KEY}";
          transport = "openai_chat";
          discover_models = true;
        };
      }
      (lib.optionalAttrs cfg.omh.enable {
        skills.external_dirs = [ "${omhHome}/skills" ];
        plugins.entries.omh.settings.omh_home = omhHome;
      })
      (lib.optionalAttrs (pluginsEnabled != [ ]) { plugins.enabled = pluginsEnabled; })
      inst.settings
    ];

  mkMergeEnv =
    template: dst:
    pkgs.writeShellScript "hermes-merge-env" ''
      set -euo pipefail
      src=${template}
      dst=${dst}

      touch "$dst"
      keys=$(cut -d= -f1 "$src" | paste -sd'|')
      tmp=$(mktemp)

      # keep unrelated lines, replace the sops-managed ones
      grep -vE "^($keys)=" "$dst" > "$tmp" || true
      cat "$src" >> "$tmp"
      install -m 600 "$tmp" "$dst"
      rm -f "$tmp"
    '';
in
{
  inherit
    cfg
    profiles
    omhHome
    profileDir
    profileUnits
    hermesHomes
    units
    coreUnits
    syncUnits
    effectiveMcp
    mcpToYaml
    renderEnv
    allSecrets
    settingsOf
    mkMergeEnv
    ;

  templatePath = name: config.sops.templates.${name}.path;
  secretPath = name: config.sops.secrets.${name}.path;
}
