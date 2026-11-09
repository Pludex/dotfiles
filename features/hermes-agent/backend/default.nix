{
  inputs,
  config,
  base,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.hermes-agent-backend;
  app = base.app "hermes-agent";
  dataDir = app.container.data;

  hermesProvided = [ "requests" ];
  notProvided = lib.filter (d: !(lib.elem (d.pname or "") hermesProvided));

  forHermes =
    pkg:
    pkg.overridePythonAttrs (old: {
      dependencies = notProvided (old.dependencies or [ ]);
      propagatedBuildInputs = notProvided (old.propagatedBuildInputs or [ ]);
      pythonRemoveDeps = (old.pythonRemoveDeps or [ ]) ++ hermesProvided;
      pythonImportsCheck = [ ];
      doInstallCheck = false;
    });

  webNames = [
    "tavily-client"
    "context7-client"
    "firecrawl-client"
    "web-tools"
  ];

  hermesPy = pkgs.python3Packages.overrideScope (
    _: prev: lib.genAttrs webNames (n: forHermes prev.${n})
  );

  webPkgs = with hermesPy; [
    tavily-client
    context7-client
    firecrawl-client
    web-tools
  ];
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    ./options.nix
    ./main.nix
    ./profiles.nix
    ./omh.nix
    ./soul.nix
  ];

  services.hermes-agent-backend = {
    enable = true;
    sessionTokenSecret = "desktop-token";
    allowedUsersSecret = "discord/user-id";
    apiServer.enable = true;
    extraPythonPackages = webPkgs;

    soul = {
      enable = true;
      base = ../soul/base.md;
    };

    settings = {
      agent.disabled_toolsets = [
        "web"
        "browser"
      ];

      skills.external_dirs = [
        "${dataDir}/omh/skills"
      ];

      terminal.env_passthrough = [
        "OMNIROUTE_BASE_URL"
        "OMNIROUTE_API_KEY"
      ];
    };
    envs = {
      OMNIROUTE_BASE_URL = cfg.omniroute.baseUrl;
    };

    omh = {
      enable = true;
      chains = {
        quick = [
          {
            model = "chat-fast";
            reasoningEffort = "low";
          }
        ];
        visual-engineering = [
          {
            model = "code-std";
            reasoningEffort = "medium";
          }
        ];
        deep = [
          {
            model = "code-pro";
            reasoningEffort = "high";
          }
        ];
        ultrabrain = [
          {
            model = "agent-pro";
            reasoningEffort = "high";
          }
        ];
      };
    };
    themePack.enable = true;

    # Applied to main and every profile
    mcp = {
      omniroute = {
        url = "${cfg.omniroute.baseUrl}/api/mcp/stream";
        headers.Authorization = "Bearer \${OMNIROUTE_MANAGE_KEY}";
        secretEnv.OMNIROUTE_MANAGE_KEY = "api-keys/omniroute/manage";
      };
      github = {
        url = "https://api.githubcopilot.com/mcp/";
        headers.Authorization = "Bearer \${GITHUB_MCP_TOKEN}";
        secretEnv.GITHUB_MCP_TOKEN = "github/mcp-token";
      };
    };

    main = {
      model = "hermes";
      apiKeySecret = "api-keys/omniroute/main";
      secretEnv.API_SERVER_KEY = "api-keys/api-server";
      soul.focus = builtins.readFile ../soul/focus/default.md;
      discord = {
        tokenSecret = "discord/token";
        homeChannel = "1565701591942561912";
        homeChannelName = "main";
        freeChannels = [ "1565701591942561912" ];
      };
      # mcp.context7 = {
      #   url = "https://mcp.context7.com/mcp";
      #   headers.CONTEXT7_API_KEY = "\${CONTEXT7_API_KEY}";
      #   secretEnv.CONTEXT7_API_KEY = "api-keys/context7";
      # };

      settings = {
        skills.external_dirs = [
          "${dataDir}/skills"
          "${dataDir}/skills-active" # skills are active
        ];
      };
    };

    profiles = {
      coding = {
        model = "hermes-coding";
        apiKeySecret = "api-keys/omniroute/coding";
        soul.focus = builtins.readFile ../soul/focus/coding.md;
        discord = {
          tokenSecret = "discord/coding-token";
          homeChannel = "1565713912106844252";
          homeChannelName = "coding";
          freeChannels = [ "1565713912106844252" ];
        };

        settings = {
          skills.external_dirs = [
            "${dataDir}/profiles/coding/skills"
            "${dataDir}/profiles/coding/skills-active" # skills are active
          ];
        };
      };
      study = {
        model = "hermes-study";
        apiKeySecret = "api-keys/omniroute/study";
        soul.focus = builtins.readFile ../soul/focus/study.md;
        excludeMcp = [
          "omniroute"
          "github"
        ];
        discord = {
          tokenSecret = "discord/study-token";
          homeChannel = "1565713936043483287";
          homeChannelName = "study";
          freeChannels = [ "1565713936043483287" ];
        };

        settings = {
          skills.external_dirs = [
            "${dataDir}/profiles/study/skills"
            "${dataDir}/profiles/study/skills-active" # skills are active
          ];
        };
      };

      web = {
        soul.enable = false;
        apiKeySecret = "api-keys/omniroute/web";
        model = "web";
        settings = {
          platform_toolsets.cli = [ ];
          mcp_servers = {
            github = lib.mkForce { };
            omniroute = lib.mkForce { };
          };
        };
      };
    };
  };
}
