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
  echo "Error: Release metadata file '$RELEASE_FILE' not found." >&2
  exit 1
fi

CURRENT_VERSION=$(jq -r '.version' "$RELEASE_FILE")

API_JSON=$(curl -fsSL \
  -H "X-Plex-Token: ${PLEX_TOKEN}" \
  -H "Accept: application/json" \
  "$API_URL")

LATEST_VERSION=$(printf '%s' "$API_JSON" | jq -r '.computer.Linux.version // empty')

if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not read .computer.Linux.version from Plex API response. Check PLEX_TOKEN and Plex Pass status." >&2
  exit 1
fi

echo "Current version: $CURRENT_VERSION"
echo "Latest Plex Pass version: $LATEST_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date. Nothing to commit."
  exit 0
fi

AMD64_URL=$(printf '%s' "$API_JSON" | jq -r '
  .computer.Linux.releases[]
  | select(.distro == "debian" and .build == "linux-x86_64")
  | .url
' | head -n1)

ARM64_URL=$(printf '%s' "$API_JSON" | jq -r '
  .computer.Linux.releases[]
  | select(.distro == "debian" and .build == "linux-aarch_64")
  | .url
' | head -n1)

if [ -z "$AMD64_URL" ] || [ -z "$ARM64_URL" ]; then
  echo "Error: Could not resolve Debian amd64 or arm64 URL from API response." >&2
  exit 1
fi

echo "Prefetching x86_64-linux package..."
AMD64_RAW_HASH=$(nix-prefetch-url --type sha256 "$AMD64_URL")
AMD64_SRI_HASH=$(nix hash convert --hash-algo sha256 --to sri "$AMD64_RAW_HASH")

echo "Prefetching aarch64-linux package..."
ARM64_RAW_HASH=$(nix-prefetch-url --type sha256 "$ARM64_URL")
ARM64_SRI_HASH=$(nix hash convert --hash-algo sha256 --to sri "$ARM64_RAW_HASH")

TMP_FILE="${RELEASE_FILE}.tmp"
jq \
  --arg ver "$LATEST_VERSION" \
  --arg amd_url "$AMD64_URL" \
  --arg amd_hash "$AMD64_SRI_HASH" \
  --arg arm_url "$ARM64_URL" \
  --arg arm_hash "$ARM64_SRI_HASH" \
  '
  .version = $ver
  | .systems["x86_64-linux"].url = $amd_url
  | .systems["x86_64-linux"].hash = $amd_hash
  | .systems["aarch64-linux"].url = $arm_url
  | .systems["aarch64-linux"].hash = $arm_hash
  ' "$RELEASE_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$RELEASE_FILE"

# Evaluate flake structure without building the unfree package
nix flake show --json >/dev/null

TAG_NAME="${TAG_PREFIX}${LATEST_VERSION}"

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

