#!/usr/bin/env bash
# Shared helpers for the Plex release scripts. Source this file, do not execute it.

RELEASE_FILE="${RELEASE_FILE:-plex-release.json}"
API_URL="${API_URL:-https://plex.tv/api/downloads/5.json?channel=plexpass}"

require_api_env() {
  if [ -z "${PLEX_TOKEN:-}" ]; then
    echo "Error: PLEX_TOKEN environment variable is required." >&2
    exit 1
  fi
}

require_cmds() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: Required command '$cmd' not found in PATH." >&2
      exit 1
    fi
  done
}

fetch_api_json() {
  curl -fsSL \
    -H "X-Plex-Token: ${PLEX_TOKEN}" \
    -H "Accept: application/json" \
    "$API_URL"
}

current_version() {
  if [ -f "$RELEASE_FILE" ]; then
    jq -r '.version // ""' "$RELEASE_FILE"
  else
    printf ''
  fi
}

latest_version() {
  printf '%s' "$1" | jq -r '.computer.Linux.version // empty'
}

# set_output is a no-op outside GitHub Actions so the scripts stay runnable by hand.
set_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  fi
}

# step_summary is a no-op outside GitHub Actions.
step_summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}
