{
  config,
  lib,
  pkgs,
  ...
}:
let
  omnirouteModel = "auto";

  playwright-cli = pkgs.writeShellScriptBin "playwright-cli" ''
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    exec ${lib.getExe' pkgs.nodejs_22 "npx"} -y @playwright/cli@latest "$@"
  '';

  graphify = pkgs.writeShellScriptBin "graphify" ''
    exec ${lib.getExe pkgs.uv} tool run --from graphifyy graphify "$@"
  '';

  extraPackages = [
    pkgs.nodejs_22
    pkgs.uv
    playwright-cli
    graphify
  ];

  claude = pkgs.symlinkJoin {
    name = "claude-code-wrapped";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --prefix PATH : ${lib.makeBinPath extraPackages} \
        --run 'export PATH="$PATH:$HOME/.local/bin"'
    '';
    meta = pkgs.claude-code.meta;
  };
in
{
  home.packages = [
    playwright-cli
    graphify
  ];

  sops.secrets."api-keys/omniroute/claude-code" = { };

  programs.claude-code = {
    enable = true;
    package = claude;
    settings = {
      apiKeyHelper = "${lib.getExe' pkgs.coreutils "cat"} ${
        config.sops.secrets."api-keys/omniroute/claude-code".path
      }";
      env = {
        ANTHROPIC_BASE_URL = "http://localhost:20128";
        ANTHROPIC_API_KEY = "";
        ANTHROPIC_MODEL = omnirouteModel;
        ANTHROPIC_DEFAULT_SONNET_MODEL = omnirouteModel;
        ANTHROPIC_DEFAULT_OPUS_MODEL = omnirouteModel;
        ANTHROPIC_DEFAULT_HAIKU_MODEL = omnirouteModel;
        CLAUDE_CODE_SUBAGENT_MODEL = omnirouteModel;
        CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT = "1";
      };
      extraKnownMarketplaces = {
        ponytail.source = {
          source = "github";
          repo = "DietrichGebert/ponytail";
        };
        addy-agent-skills.source = {
          source = "github";
          repo = "addyosmani/agent-skills";
        };
        playwright-cli.source = {
          source = "github";
          repo = "microsoft/playwright-cli";
        };
      };
      enabledPlugins = {
        "ponytail@ponytail" = true;
        "agent-skills@addy-agent-skills" = true;
        "playwright-cli@playwright-cli" = true;
      };
    };
    mcpServers.playwright = {
      command = lib.getExe pkgs.playwright-mcp;
      env = {
        PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
    };

    mcpServers.basic-memory = {
      type = "http";
      url = "http://127.0.0.1:8765/mcp";
    };

    memory.text = ''
      # Shared memory
      Use the basic-memory MCP tools as long-term memory shared across clients.
      - At session start, search for notes relevant to the current project or task.
      - Save durable facts only: decisions, conventions, project state.
      - Never save secrets or raw chat logs.
      - Update an existing note instead of creating a duplicate.
    '';
  };
}
