#!/usr/bin/env bash
set -euo pipefail

RELEASE_FILE="${RELEASE_FILE:-plex-release.json}"
API_URL="${API_URL:-https://plex.tv/api/downloads/5.json?channel=public}"
TAG_PREFIX="${TAG_PREFIX:-}"

if [ -z "${PLEX_TOKEN:-}" ]; then
  echo "Error: PLEX_TOKEN environment variable is required." >&2
  exit 1
fi

for cmd in curl jq nix nix-prefetch-url git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' not found in PATH." >&2
    exit 1
  fi
done

if [ ! -f "$RELEASE_FILE" ]; then
  printf '{"version":"","systems":{}}\n' > "$RELEASE_FILE"
fi

CURRENT_VERSION=$(jq -r '.version // ""' "$RELEASE_FILE")

API_JSON=$(curl -fsSL \
  -H "X-Plex-Token: ${PLEX_TOKEN}" \
  -H "Accept: application/json" \
  "$API_URL")

LATEST_VERSION=$(printf '%s' "$API_JSON" | jq -r '.computer.Linux.version // empty')

if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not read .computer.Linux.version from Plex API response." >&2
  exit 1
fi

echo "Current version: ${CURRENT_VERSION:-<none>}"
echo "Latest Plex Pass version: $LATEST_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date. Nothing to commit."
  exit 0
fi

find_deb_url() {
  local build_name="$1"
  printf '%s' "$API_JSON" | jq -r --arg build "$build_name" '
    [
      .computer.Linux.releases[]
      | select(.distro == "debian" and .build == $build)
      | .url
    ][0] // empty
  '
}

prefetch_sri_hash() {
  local pkg_url="$1"
  local raw_hash
  raw_hash=$(nix-prefetch-url --type sha256 "$pkg_url")
  nix hash convert --hash-algo sha256 --to sri "$raw_hash"
}

AMD64_URL=$(find_deb_url "linux-x86_64")
ARM64_URL=$(find_deb_url "linux-aarch64")

if [ -z "$AMD64_URL" ]; then
  echo "Error: Could not resolve Debian linux-x86_64 URL." >&2
  exit 1
fi

if [ -z "$ARM64_URL" ]; then
  echo "Error: Could not resolve Debian linux-aarch64 URL." >&2
  exit 1
fi

echo "Prefetching x86_64-linux..."
AMD64_HASH=$(prefetch_sri_hash "$AMD64_URL")

echo "Prefetching aarch64-linux..."
ARM64_HASH=$(prefetch_sri_hash "$ARM64_URL")

SYSTEMS_JSON=$(jq -n \
  --arg amd_url "$AMD64_URL" \
  --arg amd_hash "$AMD64_HASH" \
  --arg arm_url "$ARM64_URL" \
  --arg arm_hash "$ARM64_HASH" \
  '{
    "x86_64-linux": { "url": $amd_url, "hash": $amd_hash },
    "aarch64-linux": { "url": $arm_url, "hash": $arm_hash }
  }')

for spec in "armv7l-linux:linux-armv7neon" "i686-linux:linux-x86"; do
  nix_sys="${spec%%:*}"
  plex_build="${spec#*:}"
  pkg_url=$(find_deb_url "$plex_build")
  if [ -n "$pkg_url" ]; then
    echo "Prefetching ${nix_sys} (${plex_build})..."
    pkg_hash=$(prefetch_sri_hash "$pkg_url")
    SYSTEMS_JSON=$(printf '%s' "$SYSTEMS_JSON" | jq \
      --arg sys "$nix_sys" \
      --arg url "$pkg_url" \
      --arg hash "$pkg_hash" \
      '. + { ($sys): { "url": $url, "hash": $hash } }')
  fi
done

TMP_FILE="${RELEASE_FILE}.tmp"
jq -n \
  --arg ver "$LATEST_VERSION" \
  --argjson systems "$SYSTEMS_JSON" \
  '{ version: $ver, systems: $systems }' > "$TMP_FILE"
mv "$TMP_FILE" "$RELEASE_FILE"

nix flake show --json >/dev/null

CLEAN_VERSION="${LATEST_VERSION#v}"
if [[ "$TAG_PREFIX" == *v ]] && [[ "$CLEAN_VERSION" == v* ]]; then
  TAG_NAME="${TAG_PREFIX}${CLEAN_VERSION#v}"
else
  TAG_NAME="${TAG_PREFIX}${CLEAN_VERSION}"
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add "$RELEASE_FILE"
git commit -m "plex: update to ${LATEST_VERSION}"

if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
  echo "Tag ${TAG_NAME} already exists locally; skipping tag creation."
else
  git tag -a "${TAG_NAME}" -m "Plex Media Server ${LATEST_VERSION}"
fi

git push origin HEAD --follow-tags

