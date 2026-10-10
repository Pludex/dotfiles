{
  config,
  lib,
  pkgs,
  ...
}:
let
  claude = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      if [ -z "''${ANTHROPIC_BASE_URL:-}" ] && [ -z "''${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        ANTHROPIC_AUTH_TOKEN="$(cat ${config.sops.secrets."api-keys/openrouter/claude-code".path})"
        export ANTHROPIC_AUTH_TOKEN
        export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
      fi

      exec ${lib.getExe pkgs.claude-code} "$@"
    '';
  };
in
{
  sops.secrets."api-keys/openrouter/claude-code" = { };

  programs.claude-code = {
    enable = true;
    package = claude;

    settings = {
      CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT = "1";
      ANTHROPIC_DEFAULT_SONNET_MODEL = "openrouter/free";
      ANTHROPIC_API_KEY = "";
    };
  };
}
