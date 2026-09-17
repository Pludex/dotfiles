{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.mango;
  # mango/mmsg binaries actually come from the official home-manager module's
  # package option, not from `programs.mango` (which only holds our custom
  # startSessionWithApps settings here).
  mangoPackage = config.wayland.windowManager.mango.package;

  startAppType = types.submodule {
    options = {
      cmd = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell command used to launch the application. Use this OR
          `desktopFile`, not both.
        '';
        example = "kitty --class scratch-term";
      };

      desktopFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Name (or path) of a .desktop file to launch via `gtk-launch`,
          e.g. "firefox.desktop". Use this OR `cmd`.
        '';
        example = "org.mozilla.firefox.desktop";
      };

      tags = mkOption {
        type = types.listOf types.ints.positive;
        default = [ ];
        description = "List of tags to assign to this application's window (via mmsg IPC).";
        example = [
          1
          3
        ];
      };

      monitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Target monitor to wait on / assign tags on (defaults to whichever
          monitor is focused when mmsg runs). Currently only meant to be
          passed to `-o`/`get monitor` if you extend the script below.
        '';
      };

      switchToTag = mkOption {
        type = types.bool;
        default = false;
        description = "After assigning tags, switch the view to the first tag in `tags`.";
      };

      delay = mkOption {
        type = types.str;
        default = "0";
        description = ''
          Delay before launching this application (passed straight to
          `sleep`, decimals like "1.5" are supported).
        '';
      };

      waitTries = mkOption {
        type = types.ints.positive;
        default = 50;
        description = ''
          Maximum number of attempts (0.1s apart) to find the just-spawned
          client in `mmsg get all-clients` before giving up on tag
          assignment. Default 50 tries ~ 5 seconds.
        '';
      };
    };
  };

  # Strip a trailing "&" (and surrounding spaces) the user may have added to
  # `cmd` by habit — this module already backgrounds the command itself, so
  # a user-supplied trailing "&" would produce "cmd & &" in the generated
  # script, which is a bash syntax error.
  trimTrailingAmp =
    s:
    let
      m = builtins.match "(.*[^ ])[ ]*&[ ]*" s;
    in
    if m != null then builtins.head m else s;

  # Generate the script snippet for one entry
  mkEntry =
    idx: e:
    let
      label = if e.cmd != null then e.cmd else e.desktopFile;

      launchCmd =
        if e.cmd != null then
          trimTrailingAmp e.cmd
        else
          "${pkgs.glib}/bin/gtk-launch ${escapeShellArg e.desktopFile}";

      # NOTE: the "tag"/"tagsilent" dispatch names are taken from the bind=
      # syntax in config.conf (tag,<idx>,<focus?> / tagsilent,<idx>). tagsilent
      # MOVES the client to that one tag (replaces its tags), it does not add
      # a bit — so multi-tag `tags = [ a b ]` entries only end up on the last
      # tag dispatched. Fine for single-tag entries.
      tagDispatch = t: ''${mangoPackage}/bin/mmsg dispatch tagsilent,${toString t} client,"$new_id"'';
    in
    ''
      # --- entry ${toString idx}: ${label} ---
      entry_label=${escapeShellArg label}
      ${optionalString (e.delay != "0") "sleep ${e.delay}"}

      before_ids=$(get_ids)
      ${launchCmd} &

      new_id=""
      tries=0
      while [ -z "$new_id" ] && [ "$tries" -lt ${toString e.waitTries} ]; do
        after_ids=$(get_ids)
        # first id present now but not before launch — works even for
        # single-instance apps (Chromium/Vivaldi/Firefox etc.) whose spawned
        # process just relays to an already-running instance and exits
        # immediately: the new *window* still shows up as a new client id,
        # even though its pid belongs to the older, already-running process.
        new_id=$(comm -13 <(printf '%s\n' "$before_ids" | sort -u) <(printf '%s\n' "$after_ids" | sort -u) | head -n1)
        [ -n "$new_id" ] && break
        sleep 0.1
        tries=$((tries + 1))
      done

      if [ -n "$new_id" ]; then
      ${concatMapStringsSep "\n" tagDispatch e.tags}
        ${optionalString (
          e.switchToTag && e.tags != [ ]
        ) ''${mangoPackage}/bin/mmsg dispatch tag,${toString (head e.tags)},1 client,"$new_id"''}
      else
        echo "startSessionWithApps: no new client appeared for entry ${toString idx} ($entry_label) after ${toString e.waitTries} tries" >&2
      fi
    '';
in
{
  options.programs.mango.settings.startSessionWithApps = mkOption {
    type = types.listOf startAppType;
    default = [ ];
    description = ''
      List of applications to launch with the Mango session. Each one can
      be assigned to one or more tags as soon as its window appears, via
      mmsg IPC (get all-clients is diffed before/after launch to find the
      new client id, then dispatch tagsilent/tag assigns it).
    '';
    example = literalExpression ''
      [
        { cmd = "kitty"; tags = [ 1 ]; }
        { desktopFile = "firefox.desktop"; tags = [ 2 ]; switchToTag = true; }
        { cmd = "obsidian"; tags = [ 3 5 ]; delay = "1.5"; }
      ]
    '';
  };

  options.programs.mango._internal.startSessionWithApps-sh = mkOption {
    type = types.package;
    internal = true;
    readOnly = true;
    description = ''
      Script (derivation) generated from startSessionWithApps: launches each
      app and assigns tags to its client via mmsg. Add it to exec-once
      yourself (or wire it into autostart_sh) — this option no longer does
      that automatically.
    '';
  };

  config = mkIf (cfg.settings.startSessionWithApps != [ ]) {
    assertions = [
      {
        assertion = all (e: (e.cmd != null) != (e.desktopFile != null)) cfg.settings.startSessionWithApps;
        message = ''
          programs.mango.settings.startSessionWithApps: every entry must set
          EXACTLY ONE of `cmd` or `desktopFile`.
        '';
      }
    ];

    programs.mango._internal.startSessionWithApps-sh = pkgs.writeShellApplication {
      name = "mango-start-session-with-apps";
      runtimeInputs = [
        pkgs.jq
        mangoPackage
      ];
      text = ''
        set -uo pipefail

        get_ids() {
          ${mangoPackage}/bin/mmsg get all-clients \
            | ${pkgs.jq}/bin/jq -r '.clients[].id'
        }

        # Entries run SEQUENTIALLY on purpose (not backgrounded as a group):
        # the before/after client-id diff needs a stable baseline between
        # entries, which breaks if several entries launch at once. Each
        # app's own process is still started in the background (`&`), so a
        # slow-to-render app doesn't block the compositor — only the next
        # *entry* in this list waits for the current one to resolve (or time
        # out after its waitTries).
        ${concatStringsSep "\n" (imap0 mkEntry cfg.settings.startSessionWithApps)}
      '';
    };
  };
}
