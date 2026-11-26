#!/usr/bin/env bash
# Compare the pinned Plex version against the latest Plex Pass release.
# Emits `version` and `changed` (true|false) for the workflow's update job to gate on.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

require_api_env
require_cmds curl jq

CURRENT_VERSION=$(current_version)

API_JSON=$(fetch_api_json)

LATEST_VERSION=$(latest_version "$API_JSON")

if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not read .computer.Linux.version from Plex API response." >&2
  exit 1
fi

echo "Current version: ${CURRENT_VERSION:-<none>}"
echo "Latest Plex Pass version: $LATEST_VERSION"

set_output version "$LATEST_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date. Nothing to do."
  set_output changed false
  step_summary "### Plex already at \`${CURRENT_VERSION}\` — nothing to update"
else
  echo "Update available."
  set_output changed true
  step_summary "### Plex update available: \`${CURRENT_VERSION:-<none>}\` → \`${LATEST_VERSION}\`"
fi
