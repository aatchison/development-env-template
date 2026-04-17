#!/usr/bin/env bash
# Regenerate overlays into a temp dir and diff against committed copies.
# Exits non-zero if any overlay differs (indicating drift).
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not inside a git repo" >&2
  exit 1
}
cd "$REPO_ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

./scripts/build-overlays.sh --output-dir "$tmp" >/dev/null

drift=0
for f in "$tmp"/*.json; do
  name="$(basename "$f")"
  if ! diff -u ".devcontainer/overlays/$name" "$f"; then
    echo "DRIFT DETECTED in $name" >&2
    drift=1
  fi
done

if [[ $drift -eq 1 ]]; then
  echo "Run ./scripts/build-overlays.sh to regenerate overlays." >&2
  exit 1
fi
echo "No overlay drift."
