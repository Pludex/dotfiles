{
  inputs,
  config,
  ...
}:
let
  cfg = config.services.hermes-agent-backend;
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    ./options.nix
    ./main.nix
    ./profiles.nix
    ./omh.nix
  ];

  services.hermes-agent-backend = {
    enable = true;
    sessionTokenSecret = "desktop-token";
    allowedUsersSecret = "discord/user-id";
    apiServer.enable = true;

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
      discord = {
        tokenSecret = "discord/token";
        homeChannel = "1565701591942561912";
        homeChannelName = "main";
        freeChannels = [ "1565701591942561912" ];
      };
      mcp.context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "\${CONTEXT7_API_KEY}";
        secretEnv.CONTEXT7_API_KEY = "api-keys/context7";
      };
    };

    profiles = {
      coding = {
        model = "hermes-coding";
        apiKeySecret = "api-keys/omniroute/coding";
        discord = {
          tokenSecret = "discord/coding-token";
          homeChannel = "1565713912106844252";
          homeChannelName = "coding";
          freeChannels = [ "1565713912106844252" ];
        };
      };
      study = {
        model = "hermes-study";
        apiKeySecret = "api-keys/omniroute/study";
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
      };
    };
  };
}
