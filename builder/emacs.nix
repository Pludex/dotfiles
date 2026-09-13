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

      cfg = import "${base.emacs}/default.nix" { inherit lib pkgs; };

      toElispValue =
        value:
        if builtins.isBool value then
          (if value then "t" else "nil")
        else if value == null then
          "nil"
        else if builtins.isInt value || builtins.isFloat value then
          toString value
        else if builtins.isString value then
          ''"${lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] value}"''
        else if builtins.isList value then
          "'(" + lib.concatMapStringsSep " " toElispValue value + ")"
        else
          throw "Unsupported globalVar type: ${builtins.toJSON value}";

      flattenGlobalVar =
        prefix: attrs:
        lib.concatLists (
          lib.mapAttrsToList (
            k: v:
            let
              name = if prefix == "" then k else "${prefix}-${k}";
            in
            if builtins.isAttrs v then
              flattenGlobalVar name v
            else
              [
                {
                  inherit name;
                  value = v;
                }
              ]
          ) attrs
        );

      globalVarLines = map ({ name, value }: "(setq ${name} ${toElispValue value})") (
        flattenGlobalVar "" (cfg.globalVar or { })
      );

      generatedVarsEl = pkgs.writeText "generated-vars.el" (
        lib.concatStringsSep "\n" (globalVarLines ++ [ "" ])
      );

      copyExtraFiles = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (relPath: src: ''
          mkdir -p "$out/$(dirname "${relPath}")"
          cp -r ${src} "$out/${relPath}"
        '') (cfg.extraFile or { })
      );

      configEmacs = pkgs.runCommand "emacs-config" { } ''
        mkdir -p $out
        cp -r ${base.emacs}/. $out/
        chmod -R u+w $out
        cat ${generatedVarsEl} ${base.emacs}/init.el > $out/init.el
        ${copyExtraFiles}
      '';

      emacsWithPackages = pkgs.emacsWithPackagesFromUsePackage {
        config = "${configEmacs}/packages.el";
        alwaysEnsure = true;
      };

      emacsWrapped = pkgs.writeShellScriptBin "emacs" ''
        exec ${emacsWithPackages}/bin/emacs --init-directory="${configEmacs}" "$@"
      '';
    in
    emacsWrapped;
}
