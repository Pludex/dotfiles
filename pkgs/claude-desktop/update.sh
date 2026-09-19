set -euo pipefail

REPO_BASE="https://downloads.claude.ai/claude-desktop/apt/stable"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="${SCRIPT_DIR}/input.json"

if ! command -v nix >/dev/null 2>&1; then
  echo "error: 'nix' not found on PATH - needed to compute sha256 hashes" >&2
  exit 1
fi

ARCHES=("amd64" "arm64")
if [[ $# -ge 1 ]]; then
  ARCHES=("$1")
fi

get_latest_deb_path() {
  local arch="$1"
  local packages_url="${REPO_BASE}/dists/stable/main/binary-${arch}/Packages"

  curl -fsSL "$packages_url" \
    | grep '^Filename: pool/main/c/claude-desktop/claude-desktop_' \
    | sort -V \
    | tail -n 1 \
    | cut -d' ' -f2
}

# Prefetches $1 (a URL) and prints its sha256 in SRI form (sha256-xxxx...),
# the same format Nix's fetchurl `hash` argument expects.
get_sha256() {
  local url="$1"
  local out

  # Preferred: modern Nix, gives SRI hash directly.
  if out="$(nix store prefetch-file --json "$url" 2>/dev/null)"; then
    printf '%s' "$out" | grep -o '"hash"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4
    return 0
  fi

  # Fallback for older Nix: nix-prefetch-url gives a base32 hash, convert to SRI.
  local base32hash
  base32hash="$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -n 1)"
  if [[ -n "$base32hash" ]]; then
    nix hash convert --hash-algo sha256 --to sri "$base32hash" 2>/dev/null \
      || nix hash to-sri --type sha256 "$base32hash" 2>/dev/null
    return 0
  fi

  return 1
}

json_escape() {
  # minimal JSON string escaping for the values we produce (urls/versions
  # only ever contain safe characters, but escape defensively anyway)
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

entries=()

for arch in "${ARCHES[@]}"; do
  echo "Looking up latest claude-desktop for ${arch}..." >&2

  deb_path="$(get_latest_deb_path "$arch" || true)"

  if [[ -z "$deb_path" ]]; then
    echo "  -> no package found for ${arch} (repo unreachable, or arch not published), skipping" >&2
    continue
  fi

  # deb_path looks like: pool/main/c/claude-desktop/claude-desktop_0.15.3_amd64.deb
  filename="$(basename "$deb_path")"
  version="$(echo "$filename" | sed -E 's/^claude-desktop_([^_]+)_.*\.deb$/\1/')"
  url="${REPO_BASE}/${deb_path}"

  echo "  -> version ${version}: ${url}" >&2
  echo "  -> prefetching sha256 (this downloads the .deb)..." >&2

  sha256="$(get_sha256 "$url" || true)"
  if [[ -z "$sha256" ]]; then
    echo "  -> failed to compute sha256 for ${arch}, skipping" >&2
    continue
  fi

  echo "  -> sha256: ${sha256}" >&2

  entries+=("  \"$(json_escape "$arch")\": {\"url\": \"$(json_escape "$url")\", \"version\": \"$(json_escape "$version")\", \"sha256\": \"$(json_escape "$sha256")\"}")
done

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "No packages found for any requested arch, aborting without writing $OUT_FILE" >&2
  exit 1
fi

{
  echo "{"
  for i in "${!entries[@]}"; do
    sep=","
    [[ $i -eq $((${#entries[@]} - 1)) ]] && sep=""
    echo "${entries[$i]}${sep}"
  done
  echo "}"
} > "$OUT_FILE"

echo "Written to: $OUT_FILE" >&2
cat "$OUT_FILE"
