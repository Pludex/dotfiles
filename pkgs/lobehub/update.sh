#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#curl nixpkgs#jq nixpkgs#nodejs_22 nixpkgs#prefetch-npm-deps nixpkgs#gnutar nixpkgs#gzip nixpkgs#coreutils nixpkgs#gnugrep --command bash

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

cli_req="${1:-latest}"
desktop_req="${2:-}"

gh_args=(-fsSL)
if [[ -n ${GITHUB_TOKEN:-} ]]; then
  gh_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

meta="$(curl -fsSL "https://registry.npmjs.org/@lobehub/cli/${cli_req}")"
cli_version="$(jq -r .version <<<"$meta")"
cli_url="$(jq -r .dist.tarball <<<"$meta")"
cli_hash="$(jq -r .dist.integrity <<<"$meta")"

curl -fsSL "$cli_url" | tar xz -C "$tmp"

jq 'del(.devDependencies, .scripts)' "$tmp/package/package.json" >"$tmp/package.json"
if grep -q 'workspace:' "$tmp/package.json"; then
  echo "error: workspace: references remain in package.json" >&2
  exit 1
fi

mkdir "$tmp/lock"
cp "$tmp/package.json" "$tmp/lock/package.json"
(
  cd "$tmp/lock"
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund
)

cp "$tmp/package.json" package.json
cp "$tmp/lock/package-lock.json" package-lock.json
npm_deps_hash="$(prefetch-npm-deps package-lock.json)"

if [[ -z $desktop_req ]]; then
  releases="$(curl "${gh_args[@]}" "https://api.github.com/repos/lobehub/lobehub/releases?per_page=100")"
  has_appimage='any(.assets[]; .name | endswith(".AppImage"))'

  tag="$(jq -r "[.[] | select(.draft == false and .prerelease == false and $has_appimage)][0].tag_name // empty" <<<"$releases")"
  if [[ -z $tag ]]; then
    echo "warning: no stable release with an AppImage, falling back to a prerelease" >&2
    tag="$(jq -r "[.[] | select(.draft == false and (.tag_name | test(\"nightly\") | not) and $has_appimage)][0].tag_name // empty" <<<"$releases")"
  fi
  [[ -n $tag ]] || {
    echo "error: no release with an AppImage found" >&2
    exit 1
  }
else
  tag="v${desktop_req#v}"
fi

desktop_version="${tag#v}"
desktop_url="https://github.com/lobehub/lobehub/releases/download/${tag}/LobeHub-${desktop_version}.AppImage"
desktop_hash="$(nix store prefetch-file --json --hash-type sha256 "$desktop_url" | jq -r .hash)"

jq -n \
  --arg cliVersion "$cli_version" \
  --arg cliUrl "$cli_url" \
  --arg cliHash "$cli_hash" \
  --arg npmDepsHash "$npm_deps_hash" \
  --arg desktopVersion "$desktop_version" \
  --arg desktopUrl "$desktop_url" \
  --arg desktopHash "$desktop_hash" \
  '{
    cli: {
      version: $cliVersion,
      url: $cliUrl,
      hash: $cliHash,
      npmDepsHash: $npmDepsHash
    },
    desktop: {
      version: $desktopVersion,
      url: $desktopUrl,
      hash: $desktopHash
    }
  }' >default.json.tmp
mv default.json.tmp default.json

echo "cli ${cli_version}, desktop ${desktop_version}" >&2
