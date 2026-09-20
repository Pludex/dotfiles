# modules/home/programs/warp.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.programs.warp;

  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

  dir = "warp-terminal";

  # Either a ready-made file or an attrset rendered with the given format
  # (`name` defaults to the attribute name, shown in the theme picker / `+` menu)
  render =
    format: ext: name: value:
    if builtins.isAttrs value && !(lib.isDerivation value) then
      format.generate "warp-${name}.${ext}" ({ inherit name; } // value)
    else
      value;

  # Paths below are relative to $XDG_CONFIG_HOME
  configFiles =
    lib.optionalAttrs (cfg.settings != { }) {
      "${dir}/settings.toml" = tomlFormat.generate "warp-settings.toml" cfg.settings;
    }
    // lib.optionalAttrs (cfg.keybinds != { }) {
      "${dir}/keybindings.yaml" = yamlFormat.generate "warp-keybindings.yaml" cfg.keybinds;
    };

  # Paths below are relative to $XDG_DATA_HOME
  themeFiles = lib.mapAttrs' (
    name: value: lib.nameValuePair "${dir}/themes/${name}.yaml" (render yamlFormat "yaml" name value)
  ) cfg.theme;

  tabConfigFiles = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "${dir}/tab_configs/${name}.toml" (render tomlFormat "toml" name value)
  ) cfg.tabConfigs;

  toFileAttrs = lib.mapAttrs (_: source: { inherit source; });

  installAll =
    base: files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (rel: source: ''run install -Dm644 ${source} "${base}/${rel}"'') files
    );
in
{
  options.programs.warp = {
    enable = mkEnableOption "Warp terminal";

    package = mkPackageOption pkgs "warp-terminal" { };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          appearance.text = {
            font_name = "JetBrains Mono";
            font_size = 14.0;
          };
          terminal.input.syntax_highlighting = true;
        }
      '';
      description = "Rendered to `$XDG_CONFIG_HOME/warp-terminal/settings.toml`.";
    };

    keybinds = mkOption {
      type = yamlFormat.type;
      default = { };
      description = "Rendered to `$XDG_CONFIG_HOME/warp-terminal/keybindings.yaml`.";
    };

    theme = mkOption {
      type = types.attrsOf (types.either types.path yamlFormat.type);
      default = { };
      example = lib.literalExpression ''
        {
          my-theme = {
            accent = "#268bd2";
            background = "#002b36";
            foreground = "#839496";
            details = "darker";
            terminal_colors = {
              normal = {
                black = "#073642"; red = "#dc322f"; green = "#859900"; yellow = "#b58900";
                blue = "#268bd2"; magenta = "#d33682"; cyan = "#2aa198"; white = "#eee8d5";
              };
              bright = {
                black = "#002b36"; red = "#cb4b16"; green = "#586e75"; yellow = "#657b83";
                blue = "#839496"; magenta = "#6c71c4"; cyan = "#93a1a1"; white = "#fdf6e3";
              };
            };
          };
          from-file = ./warp/other-theme.yaml;
        }
      '';
      description = ''
        Custom themes, each written to
        `$XDG_DATA_HOME/warp-terminal/themes/<name>.yaml`. The value is either
        a YAML file or an attrset using Warp's theme schema.
      '';
    };

    tabConfigs = mkOption {
      type = types.attrsOf (types.either types.path tomlFormat.type);
      default = { };
      example = lib.literalExpression ''
        {
          dev_server = {
            name = "Editor + Server";
            color = "green";
            panes = [
              { id = "root"; split = "horizontal"; children = [ "editor" "server" ]; }
              { id = "editor"; type = "terminal"; directory = "~/code/my-app"; commands = [ "nvim ." ]; is_focused = true; }
              { id = "server"; type = "terminal"; directory = "~/code/my-app"; commands = [ "npm run dev" ]; }
            ];
          };
          from_file = ./warp/other_tab.toml;
        }
      '';
      description = ''
        Tab configs, each written to
        `$XDG_DATA_HOME/warp-terminal/tab_configs/<name>.toml` (Warp recommends
        snake_case names). The value is either a TOML file or an attrset using
        Warp's tab config schema; the first entry of `panes` is the root of the
        pane tree.
      '';
    };

    mutable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Warp writes back to `settings.toml`, `keybindings.yaml` and tab configs
        when they are changed in its UI, which fails on read-only store
        symlinks. When enabled, writable copies are installed on every
        activation instead of symlinks (UI changes persist until the next
        switch, then get overwritten). Entries removed from the Nix config are
        not deleted from disk. Does not affect themes.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "programs.warp only knows the Linux (XDG) paths of Warp.";
      }
    ];

    home.packages = [ cfg.package ];

    xdg.configFile = mkIf (!cfg.mutable) (toFileAttrs configFiles);

    xdg.dataFile = toFileAttrs (themeFiles // lib.optionalAttrs (!cfg.mutable) tabConfigFiles);

    home.activation.warpConfig = mkIf cfg.mutable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${installAll config.xdg.configHome configFiles}
        ${installAll config.xdg.dataHome tabConfigFiles}
      ''
    );
  };
}
