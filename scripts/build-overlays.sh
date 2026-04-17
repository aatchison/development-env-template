#!/usr/bin/env bash
# Generate overlay devcontainer.json files from baseline + delta JSON.
# Usage: scripts/build-overlays.sh [--output-dir <dir>]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not inside a git repo" >&2
  exit 1
}
cd "$REPO_ROOT"

OUT=".devcontainer/overlays"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "--output-dir requires a value" >&2
        exit 2
      fi
      OUT="$2"
      shift 2
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done
mkdir -p "$OUT"

BASE=".devcontainer/devcontainer.json"
DELTAS_DIR=".devcontainer/overlays"

shopt -s nullglob
deltas=( "$DELTAS_DIR"/*.delta.json )
if [[ ${#deltas[@]} -eq 0 ]]; then
  echo "no deltas found in $DELTAS_DIR" >&2
  exit 1
fi

for delta in "${deltas[@]}"; do
  name="$(basename "$delta" .delta.json)"
  # jq `*` deep-merges objects but REPLACES arrays. If baseline and a delta both
  # define the same array key (e.g. "mounts"), the baseline's entries are dropped.
  jq -S -s '.[0] * .[1]' "$BASE" "$delta" > "$OUT/$name.json.tmp"
  mv "$OUT/$name.json.tmp" "$OUT/$name.json"
  echo "wrote $OUT/$name.json"
done
