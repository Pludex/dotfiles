#!/usr/bin/env nix
#! nix shell nixpkgs#curl nixpkgs#jq --command bash
set -euo pipefail
cd "$(dirname "$0")"

channel="${1:-stable}"

version=$(curl -fsSL https://releases.warp.dev/channel_versions.json |
  jq -r --arg c "$channel" '.[$c].version // empty' |
  sed 's/^v//')
[ -n "$version" ] || {
  echo "Could not get version for channel '$channel'" >&2
  exit 1
}

tmp=$(mktemp)
echo '{}' >"$tmp"

for arch in x86_64 aarch64; do
  url="https://releases.warp.dev/${channel}/v${version}/warp-terminal-v${version}-1-${arch}.pkg.tar.zst"
  if sha=$(nix store prefetch-file --json "$url" 2>/dev/null | jq -r .hash); then
    jq --arg a "$arch" --arg u "$url" --arg s "$sha" --arg v "$version" \
      '.[$a] = {url: $u, sha256: $s, version: $v}' "$tmp" >"$tmp.new"
    mv "$tmp.new" "$tmp"
  else
    echo "Skipping $arch (could not fetch $url)" >&2
  fi
done

[ "$(jq 'length' "$tmp")" -gt 0 ] || {
  echo "No architecture could be fetched" >&2
  exit 1
}

chmod 644 "$tmp"
mv "$tmp" input.json
echo "Updated to $version"
