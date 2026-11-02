{
  pkgs,
  lib,
  base,
  config,
  inputs,
  ...
}:
let
  hermes-agent = base.app "hermes-agent";
  hermesVars = import ./hermes-vars.nix { inherit pkgs lib base; };
  tokenFile = config.sops.secrets."desktop-token".path;
  tokenSnippet = ''[ -r ${tokenFile} ] && export HERMES_DESKTOP_REMOTE_TOKEN="$(cat ${tokenFile})"'';

  desktop = pkgs.symlinkJoin {
    name = "hermes-desktop";
    paths = [ pkgs.hermes.desktop ];
    meta = pkgs.hermes.desktop.meta;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in "$out"/bin/*; do
        wrapProgram "$bin" \
          --set HERMES_DESKTOP_REMOTE_URL ${hermes-agent.urls.dashboard} \
          --run 'export HERMES_HOME="$HOME/.hermes"' \
          --run 'mkdir -p "$HERMES_HOME/desktop-plugins"' \
          --run ${pkgs.lib.escapeShellArg tokenSnippet}
      done

      # symlinkJoin links .desktop files verbatim, so Exec still points at the unwrapped package
      for f in "$out"/share/applications/*.desktop; do
        [ -e "$f" ] || continue
        cp --remove-destination "$(readlink -f "$f")" "$f"
        chmod u+w "$f"
        substituteInPlace "$f" --replace-fail "${pkgs.hermes.desktop}/bin/" "$out/bin/"
      done
    '';
  };

  configFile = pkgs.writeText "hermesctl-config.json" (
    builtins.toJSON (hermesVars.vars // { desktop_bin = lib.getExe desktop; })
  );

  hermesctl =
    pkgs.runCommand "hermesctl"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "hermesctl";
      }
      ''
        ${pkgs.python3}/bin/python3 -c \
          'import ast, sys; ast.parse(open(sys.argv[1]).read())' ${./hermesctl.py}
        install -Dm755 ${./hermesctl.py} $out/libexec/hermesctl/hermesctl.py
        makeWrapper ${pkgs.python3}/bin/python3 $out/bin/hermesctl \
          --add-flags $out/libexec/hermesctl/hermesctl.py \
          --set HERMESCTL_CONFIG ${configFile}
      '';
in
{
  home.packages = [
    desktop
    hermesctl
  ];

  sops.secrets."desktop-token" = {
    mode = "0400";
    sopsFile = hermes-agent.age.defaultFile;
  };

  home.file.".hermes/desktop-plugins/theme-switcher/plugin.js".source =
    "${inputs.hermes-desktop-theme-pack}/desktop-plugin/theme-switcher/plugin.js";
}
