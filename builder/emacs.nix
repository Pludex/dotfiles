# emacs-package.nix
#
# A small Nix micro-framework for building a fully-configured Emacs package,
# with an optional "live debug" mode that lets you edit `.el` files and see
# the changes on the next Emacs restart -- no `nix build` required.
#
# Expected shape of `base` (supplied via `args`):
#
#   base.emacs        Path to a directory containing `default.nix`. This is
#                      read at *evaluation* time to configure the package
#                      (early-init content, extra packages, etc).
#
#   base.paths.emacs   (optional) Plain string: the absolute, on-disk path to
#                      that same config directory as it lives in the working
#                      tree (e.g. an editable git checkout). Used only at
#                      *runtime*, by `--debug-mode`, as the live symlink
#                      source. If omitted, debug mode falls back to the
#                      immutable copy captured at build time.
#
{ mkPkgs, args }:
let
  inherit (args) base;
in
{
  mkEmacsPackage =
    { system, ... }:
    let
      pkgs = mkPkgs { inherit system; };
      inherit (pkgs) lib;

      # -----------------------------------------------------------------
      # Diagnostics
      # -----------------------------------------------------------------
      # Fail fast with a descriptive message instead of a cryptic Nix
      # evaluation error further down the chain.
      emacsConfigDirExists = builtins.pathExists base.emacs;
    in
    if !emacsConfigDirExists then
      throw ''
        mkEmacsPackage: `base.emacs` ("${toString base.emacs}") does not exist.
        Check the `base.emacs` path in your configuration.''
    else
      let
        cfg = import "${base.emacs}/default.nix" ({ inherit pkgs; } // args);

        # Config hooks, with safe fallbacks so a minimal `default.nix`
        # (e.g. one that only sets `packagesFile`) still works.
        earlyInit = cfg.earlyInit or "";
        extraPackages = cfg.extraPackages or [ ];
        emacsPackage = cfg.package or pkgs.emacs;
        extraEmacsPackages = cfg.extraEmacsPackages or (_: [ ]);
        packagesFile = cfg.packagesFile or null;

        packagesFileExists = packagesFile != null && builtins.pathExists packagesFile;
      in
      if !packagesFileExists then
        throw ''
          mkEmacsPackage: `packagesFile` ("${toString packagesFile}") is unset
          or does not exist. Check `packagesFile` in ${toString base.emacs}/default.nix.''
      else
        let
          # ===================================================================
          # 1. Static derivations (cached; independent of the runtime wrapper)
          # ===================================================================

          # Generated early-init.el -- built once, cached by Nix like any
          # other derivation output.
          earlyInitEl = pkgs.writeText "early-init.el" earlyInit;

          # Immutable "release" init directory: a copy of the config tree
          # with the generated early-init.el overlaid on top. This is what
          # normal (non-debug) Emacs invocations use.
          configEmacs = pkgs.runCommand "emacs-config" { } ''
            mkdir -p $out
            cp -r ${base.emacs}/. $out/
            chmod -R u+w $out
            cp ${earlyInitEl} $out/early-init.el
          '';

          # Full Emacs closure with all Elisp packages pre-installed, derived
          # from the `use-package` declarations in packagesFile. This is the
          # expensive part to build, and it is never touched by debug mode.
          emacsWithPackages = pkgs.emacsWithPackagesFromUsePackage {
            config = packagesFile;
            alwaysEnsure = true;
            package = emacsPackage;
            inherit extraEmacsPackages;
          };

          # ===================================================================
          # 2. Debug live-reload support
          # ===================================================================

          # Plain-string, on-disk path used as the live symlink source.
          # Deliberately *not* interpolated as a Nix path (which would copy
          # it into the store and freeze it) -- it must stay a live string so
          # `cp -rsfT` below always reads current file contents at runtime.
          debugSourceDir = base.paths.emacs or (toString base.emacs);

          # Where the mutable debug tree is (re)built on each --debug-mode
          # run. Respects XDG_CACHE_HOME, falls back to ~/.cache. This whole
          # expression is shell syntax, evaluated at runtime, not by Nix.
          debugCacheDir = "\${XDG_CACHE_HOME:-$HOME/.cache}/emacs-debug";

          # Shell fragment (not a derivation) that refreshes the mutable
          # debug directory in place. Spliced into emacsBin below and run
          # only when --debug-mode is passed.
          prepareDebugDir = ''
            debug_dir="${debugCacheDir}"
            mkdir -p "$(dirname "$debug_dir")"

            echo "[emacs-debug] Refreshing live debug directory: $debug_dir" >&2

            # `cp -r` preserves the source directories' mode bits. If the
            # source tree (or a previous debug copy) contains read-only
            # directories -- e.g. because debugSourceDir fell back to a
            # read-only Nix store path -- `rm -rf` can fail with
            # "Permission denied" even though the files themselves are
            # owned by the user. Force everything writable first.
            if [ -e "$debug_dir" ]; then
              chmod -R u+w "$debug_dir"
              rm -rf "$debug_dir"
            fi

            # -r recursive, -s symlink, -f force, -T treat DEST as a plain
            # path rather than "inside an existing directory". This mirrors
            # every file under debugSourceDir as a symlink, so edits to a
            # .el file there are picked up the next time Emacs starts --
            # no Nix rebuild required.
            cp -rsfT "${debugSourceDir}" "$debug_dir"

            # The freshly copied tree can itself contain read-only
            # directories inherited from the source (see above). Make it
            # writable so the overlay step below, and the *next*
            # invocation's cleanup, both succeed.
            chmod -R u+w "$debug_dir"

            # Overlay the generated (real, non-symlinked) early-init.el on
            # top, so debug mode still boots with the current genFiles
            # output rather than whatever early-init.el happens to live in
            # the source tree.
            rm -f "$debug_dir/early-init.el"
            install -m644 "${earlyInitEl}" "$debug_dir/early-init.el"
          '';

          # ===================================================================
          # 3. Dynamic runtime wrapper
          # ===================================================================
          # A plain shell script rather than a `makeWrapper` flag-wrapper,
          # because it needs real control flow: stripping --debug-mode out
          # of argv and conditionally rebuilding the debug directory before
          # exec-ing the real Emacs binary. Keeping this logic in its own
          # derivation means editing the wrapper never invalidates the
          # (expensive) package-compilation cache above.
          emacsBin = pkgs.writeShellScriptBin "emacs" ''
            set -euo pipefail

            # Expose extraPackages on PATH for this invocation only --
            # does not leak into the caller's environment.
            export PATH="${lib.makeBinPath extraPackages}:$PATH"

            debug_mode=0
            args=()

            # Strip our custom --debug-mode flag out of argv before Emacs
            # ever sees it (Emacs itself doesn't know this flag and would
            # otherwise abort with "Unknown option: --debug-mode").
            for arg in "$@"; do
              if [ "$arg" = "--debug-mode" ]; then
                debug_mode=1
              else
                args+=("$arg")
              fi
            done

            init_dir="${configEmacs}"

            if [ "$debug_mode" -eq 1 ]; then
              ${prepareDebugDir}
              init_dir="${debugCacheDir}"
            fi

            exec "${emacsWithPackages}/bin/emacs" --init-directory="$init_dir" "''${args[@]}"
          '';

          # ===================================================================
          # 4. Final package
          # ===================================================================
          # Combine the full Emacs closure (emacsclient, etc.) with the
          # custom wrapper above, then explicitly overwrite bin/emacs with
          # the wrapper -- rather than relying on symlinkJoin's file-
          # collision ordering, which is not guaranteed.
          emacsWrapped = pkgs.symlinkJoin {
            name = "emacs";
            paths = [ emacsWithPackages ];
            postBuild = ''
              rm -f $out/bin/emacs
              cp ${emacsBin}/bin/emacs $out/bin/emacs
              chmod +x $out/bin/emacs
            '';
          };
        in
        emacsWrapped;
}
