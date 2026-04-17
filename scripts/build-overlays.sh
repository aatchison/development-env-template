#!/usr/bin/env bash
# Generate overlay devcontainer.json files from baseline + delta JSON.
# Usage: scripts/build-overlays.sh [--output-dir <dir>]
set -euo pipefail

OUT=".devcontainer/overlays"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
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
  jq -S -s '.[0] * .[1]' "$BASE" "$delta" > "$OUT/$name.json"
  echo "wrote $OUT/$name.json"
done
