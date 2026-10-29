{ config, lib, pkgs, ... }:
let
  inherit (config) app;
  pemPath = config.sops.secrets."github-app/pem".path;

  githubAppCredential = pkgs.writeShellApplication {
    name = "git-credential-github-app";
    runtimeInputs = with pkgs; [ openssl curl jq coreutils ];
    text = ''
      [ "''${1:-}" = "get" ] || exit 0

      host=""
      while IFS='=' read -r key value; do
        [ -z "$key" ] && break
        [ "$key" = "host" ] && host="$value"
      done
      [ "$host" = "github.com" ] || exit 0

      b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

      now=$(date +%s)
      header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
      payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' \
        $((now - 60)) $((now + 540)) "${toString app.githubAppId}" | b64url)
      signature=$(printf '%s.%s' "$header" "$payload" \
        | openssl dgst -sha256 -sign "${pemPath}" -binary | b64url)
      jwt="$header.$payload.$signature"

      api() {
        curl -fsS \
          -H "Authorization: Bearer $jwt" \
          -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" "$@"
      }

      # Assumes the app is installed on a single account
      installation_id=$(api https://api.github.com/app/installations | jq -r '.[0].id')

      token=$(api -X POST \
        "https://api.github.com/app/installations/$installation_id/access_tokens" \
        | jq -r '.token')

      printf 'username=x-access-token\npassword=%s\n' "$token"
    '';
  };
in
{
  programs.git = lib.mkForce {
    enable = true;
    settings = {
      user = {
        inherit (app) name email;
      };
      credential."https://github.com".helper = [
        "" # reset inherited helpers
        (lib.getExe githubAppCredential)
      ];
      url."https://github.com/".insteadOf = [
        "git@github.com:"
        "ssh://git@github.com/"
      ];
    };
  };

  sops.secrets."github-app/pem" = {
    mode = "0400";
  };
}
