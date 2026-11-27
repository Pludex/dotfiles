{ pkgs, inputs, ... }@args:
let
  settings-profile = {
    "extensions.autoDisableScopes" = 0;
    "browser.ctrlTab.sortByRecentlyUsed" = true;

    "browser.tabs.allow_transparent_browser" = true;

    "browser.startup.page" = 3;
    "browser.tabs.warnOnClose" = true;

    "floorp.zenmode.enabled" = false;
    "floorp.panelSidebar.enabled" = false;

    "sidebar.verticalTabs" = true;
    "sidebar.expandOnHover" = true;

    "browser.uiCustomization.state" = builtins.readFile ./toolbar.json;
    "browser.toolbars.bookmarks.visibility" = "alway";

    # core
    "devtools.chrome.enabled" = true;
    "devtools.debugger.remote-enabled" = true;
    "devtools.debugger.prompt-connection" = false;
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

    # keymaps
    "floorp.keyboardshortcut.config" = builtins.readFile ./shortcuts.json;
    "floorp.keyboardshortcut.enabled" = true;
  }
  // customCss.settings;

  search = {
    force = true;
    default = "google";

    engines = {
      google = {
        name = "google";
        urls = [ { template = "https://www.google.com/search?q={searchTerms}"; } ];
        icon = "https://www.google.com/favicon.ico";
        definedAliases = [ ":g" ];
      };

      github = {
        name = "github";
        urls = [ { template = "https://github.com/search?q={searchTerms}&type=repositories"; } ];
        icon = "https://github.com/favicon.ico";
        definedAliases = [ ":gh" ];
      };

      nuget = {
        name = "nuget";
        urls = [ { template = "https://www.nuget.org/packages?q={searchTerms}"; } ];
        icon = "https://nuget.org/public/favicon.ico";
        definedAliases = [ ":ng" ];
      };

      nixpkgs = {
        name = "nixpkgs";
        urls = [ { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; } ];
        icon = "https://nixos.org/favicon.ico";
        definedAliases = [ ":pkgs" ];
      };

      nixos = {
        name = "nixos";
        urls = [
          { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}&type=options"; }
        ];
        icon = "https://nixos.org/favicon.ico";
        definedAliases = [ ":nos" ];
      };

      home-manager = {
        name = "home-manager";
        urls = [
          { template = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master"; }
        ];
        icon = "https://nixos.org/favicon.ico";
        definedAliases = [ ":hm" ];
      };

      youtube = {
        name = "youtube";
        urls = [ { template = "https://www.youtube.com/results?search_query={searchTerms}"; } ];
        icon = "https://youtube.com/favicon.ico";
        definedAliases = [ ":yt" ];
      };
    };
  };

  bookmarks = { };

  extensions = (import ./extensions.nix) args;
  policies = (import ./policies.nix) args;
  customCss = (import ./customCss.nix) args;

  mkProfile =
    {
      name,
      id,
      extraConfig ? { },
    }:
    {
      inherit id name;

      settings = settings-profile;
      inherit extensions search;

      userChrome = customCss.chrome;
      userContent = customCss.content;
    }
    // extraConfig;
in
{
  programs.floorp = {
    enable = true;

    inherit policies;

    profiles = {
      work = mkProfile {
        name = "work";
        id = 0;
      };

      entertainment = mkProfile {
        name = "entertainment";
        id = 1;
      };

      society = mkProfile {
        name = "society";
        id = 2;
      };
    };
  };
}
