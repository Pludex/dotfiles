#!/usr/bin/env bash
{
  if [ -z "${ZALO_UPDATE_IN_SHELL:-}" ]; then
    export ZALO_UPDATE_IN_SHELL=1
    exec nix shell nixpkgs#bash nixpkgs#curl nixpkgs#jq nixpkgs#nix \
      -c bash "${BASH_SOURCE[0]}" "$@"
  fi
}
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

arch="x86_64-linux"
file="input.json"
api="https://api.github.com/repos/doandat943/zalo-for-linux/releases"
[ -f "$file" ] || echo '{}' >"$file"

# Usage: ./update.sh [tag]
# Without an argument, use the latest release.
if [ -n "${1:-}" ]; then endpoint="tags/$1"; else endpoint="latest"; fi
release="$(curl -fsSL "$api/$endpoint")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
# The Full variant bundles Wine/GStreamer; the standard one installs them on
# first run, which cannot work from the read-only Nix store.
url="$(jq -r '[.assets[] | select(.name | endswith("-Full.AppImage"))][0].browser_download_url // empty' <<<"$release")"
[ -n "$url" ] || {
  echo "no -Full.AppImage asset in release $version" >&2
  exit 1
}

current_version="$(jq -r --arg arch "$arch" '.[$arch].version // empty' "$file")"
current_url="$(jq -r --arg arch "$arch" '.[$arch].url // empty' "$file")"
if [ "$version" = "$current_version" ] && [ "$url" = "$current_url" ]; then
  echo "already at $version"
  exit 0
fi

sha256="$(nix-prefetch-url "$url")"

tmp="$(mktemp)"
jq --arg arch "$arch" --arg url "$url" --arg sha256 "$sha256" --arg version "$version" \
  'del(.src) | .[$arch] = { url: $url, sha256: $sha256, version: $version }' \
  "$file" >"$tmp"
mv "$tmp" "$file"

echo "${current_version:-none} -> $version"
