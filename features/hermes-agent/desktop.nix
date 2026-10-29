{
  pkgs,
  base,
  config,
  inputs,
  ...
}:
let
  hermes-agent = base.app "hermes-agent";
  tokenFile = config.sops.secrets."desktop-token".path;
  tokenSnippet = ''[ -r ${tokenFile} ] && export HERMES_DESKTOP_REMOTE_TOKEN="$(cat ${tokenFile})"'';
in
{
  home.packages = [
    (pkgs.symlinkJoin {
      name = "hermes-desktop";
      paths = [ pkgs.hermes.desktop ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in "$out"/bin/*; do
          wrapProgram "$bin" \
            --set HERMES_DESKTOP_REMOTE_URL ${hermes-agent.dashboardUrl} \
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
    })
  ];

  sops.secrets."desktop-token" = {
    mode = "0400";
    sopsFile = hermes-agent.age.defaultFile;
  };

  home.file.".hermes/desktop-plugins/theme-switcher/plugin.js".source =
    "${inputs.hermes-desktop-theme-pack}/desktop-plugin/theme-switcher/plugin.js";
}
