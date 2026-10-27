{
  pkgs,
  base,
  config,
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
            --set HERMES_DESKTOP_REMOTE_URL ${hermes-agent.urlBase} \
            --run 'export HERMES_HOME="$HOME/.hermes"' \
            --run 'mkdir -p "$HERMES_HOME/desktop-plugins"' \
            --run ${pkgs.lib.escapeShellArg tokenSnippet}
        done
      '';
    })
  ];

  sops.secrets."desktop-token" = {
    mode = "0400";
    sopsFile = hermes-agent.age.defaultFile;
  };
}
