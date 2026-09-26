{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.river.settings;

  # ---- keymaps ----

  # Replace "Mod" token with keyMod, keep other modifiers as-is
  resolveModifiers =
    modifiers:
    if modifiers == "" then
      "None"
    else
      concatStringsSep "+" (map (m: if m == "Mod" then cfg.keyMod else m) (splitString "+" modifiers));

  mkDeclareModeLine = mode: "riverctl declare-mode ${mode}";

  mkMapLine =
    km:
    let
      parts =
        optional km.release "-release"
        ++ optional km.repeat "-repeat"
        ++ optional (km.layout != 0) "-layout ${toString km.layout}"
        ++ [
          km.mode
          (resolveModifiers km.modifiers)
          km.keysym
          km.command
        ];
    in
    "riverctl map ${concatStringsSep " " parts}";

  keyMapsScript = pkgs.writeShellApplication {
    name = "river-keymaps";
    text = concatStringsSep "\n" (map mkDeclareModeLine cfg.declareModes ++ map mkMapLine cfg.keymaps);
  };

  # ---- rules ----

  mkActionLine = a: if a.args == [ ] then a.action else "${a.action} ${concatStringsSep " " a.args}";

  mkRuleGroupLines =
    group:
    map (
      a: "riverctl rule-add -app-id \"${group.app-id}\" -title \"${group.title}\" ${mkActionLine a}"
    ) group.rule;

  rulesScript = pkgs.writeShellApplication {
    name = "river-rules";
    text = concatStringsSep "\n" (concatMap mkRuleGroupLines cfg.rules);
  };

  # position/dimensions need a matching float rule in the same group (AGENTS.md pitfall #3)
  needsFloatCheck =
    group:
    let
      actions = map (a: a.action) group.rule;
      needsFloat = any (
        a:
        elem a [
          "position"
          "dimensions"
        ]
      ) actions;
    in
    needsFloat -> elem "float" actions;

in
{
  options.programs.river.settings = {
    keyMod = mkOption {
      type = types.str;
      default = "Mod4";
      example = "Mod1";
      description = "Value substituted for the \"Mod\" token in keymaps.*.modifiers.";
    };

    declareModes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "locked"
        "resize"
      ];
      description = "Modes to declare via riverctl declare-mode before any keymap uses them.";
    };

    keymaps = mkOption {
      default = [ ];
      description = "List of riverctl map keybindings.";
      type = types.listOf (
        types.submodule {
          options = {
            mode = mkOption {
              type = types.str;
              default = "normal";
            };
            command = mkOption {
              type = types.str;
              description = "Command run by riverctl map. Quote it yourself when it has flags, e.g. spawn \"foot -e btop\".";
            };
            layout = mkOption {
              type = types.int;
              default = 0;
              description = "-layout <index>. 0 means the flag is omitted.";
            };
            release = mkOption {
              type = types.bool;
              default = false;
              description = "Trigger on key release (-release).";
            };
            repeat = mkOption {
              type = types.bool;
              default = false;
              description = "Repeat while key is held (-repeat).";
            };
            modifiers = mkOption {
              type = types.str;
              default = "";
              description = "Modifiers joined by \"+\", e.g. \"Mod+Shift\". Use \"Mod\" to reference keyMod.";
            };
            keysym = mkOption {
              type = types.str;
              description = "XKB keysym name, e.g. \"Return\", \"J\".";
            };
          };
        }
      );
    };

    rules = mkOption {
      default = [ ];
      description = "List of riverctl rule-add groups, grouped by app-id/title.";
      type = types.listOf (
        types.submodule {
          options = {
            app-id = mkOption {
              type = types.str;
              default = "*";
              description = "Glob pattern for -app-id.";
            };
            title = mkOption {
              type = types.str;
              default = "*";
              description = "Glob pattern for -title.";
            };
            rule = mkOption {
              default = [ ];
              description = "Actions applied to this app-id/title match.";
              type = types.listOf (
                types.submodule {
                  options = {
                    action = mkOption {
                      type = types.enum [
                        "float"
                        "no-float"
                        "ssd"
                        "csd"
                        "tags"
                        "output"
                        "position"
                        "dimensions"
                        "fullscreen"
                        "no-fullscreen"
                        "tearing"
                        "no-tearing"
                      ];
                    };
                    args = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = "Extra arguments, e.g. [\"7\"] for tags, [\"100\" \"100\"] for position.";
                    };
                  };
                }
              );
            };
          };
        }
      );
    };
  };

  options.programs.river._Results = {
    keyMaps = mkOption {
      type = types.package;
      readOnly = true;
      description = "Generated riverctl declare-mode/map script package.";
    };
    rules = mkOption {
      type = types.package;
      readOnly = true;
      description = "Generated riverctl rule-add script package.";
    };
  };

  config = {
    programs.river._Results.keyMaps = keyMapsScript;
    programs.river._Results.rules = rulesScript;

    assertions = map (group: {
      assertion = needsFloatCheck group;
      message = "river rule for app-id=\"${group.app-id}\" title=\"${group.title}\": position/dimensions requires a matching \"float\" action in the same group.";
    }) cfg.rules;
  };
}
