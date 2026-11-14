#!/usr/bin/env -S nix shell nixpkgs#curl nixpkgs#jq --command bash
set -euo pipefail

cd "$(dirname "$0")"

release=$(curl -fsSL https://api.github.com/repos/uBlockOrigin/uBOL-home/releases/latest)
version=$(jq -r .tag_name <<<"$release")
url=$(jq -r '[.assets[] | select(.name | endswith(".chromium.zip"))][0].browser_download_url' <<<"$release")
hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

jq -n --arg version "$version" --arg url "$url" --arg hash "$hash" \
  '{version: $version, url: $url, hash: $hash}' > sources.json
