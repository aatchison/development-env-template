#!/usr/bin/env bash
# Verify a built devcontainer has the tools its overlay promises.
# Runs INSIDE the built container. Takes the overlay name (without extension)
# as $1, or "baseline" for the unmodified devcontainer.json.
#
# Exits 0 on success, non-zero on any failed check.
#
# When you add a new overlay, add its case below. Unknown names fall through to
# the baseline check so the build is at least smoke-tested.
set -euo pipefail

name="${1:-baseline}"

# Every overlay should preserve the baseline tools, so every branch starts here.
baseline_check() {
  claude --version
  gh --version
  git --version
  node --version
}

case "$name" in
  baseline)
    baseline_check
    ;;
  with-claude-mount)
    baseline_check
    # The mount is a launcher concern; in CI we can only confirm the target
    # path exists (the feature doesn't create it — the bind mount does).
    test -d /home/vscode/.claude || echo "warning: ~/.claude not mounted (expected in CI)"
    ;;
  with-docker-in-docker)
    baseline_check
    docker --version
    ;;
  with-python-ruff)
    baseline_check
    python3 --version
    ruff --version
    ;;
  with-golang)
    baseline_check
    go version
    ;;
  with-argocd)
    baseline_check
    argocd version --client 2>&1 | head -3
    ;;
  with-teleport)
    baseline_check
    tsh version 2>&1 | head -3
    ;;
  with-neovim)
    baseline_check
    nvim --version | head -1
    stow --version | head -1
    ;;
  with-opencode)
    baseline_check
    # opencode's installer may place the binary in ~/.opencode/bin.
    opencode --version 2>/dev/null \
      || "$HOME/.opencode/bin/opencode" --version 2>/dev/null \
      || { echo "opencode not found"; exit 1; }
    ;;
  with-codex)
    baseline_check
    codex --version
    ;;
  with-archon)
    baseline_check
    # archon's installer may place the binary in ~/.archon/bin or similar.
    archon --version 2>/dev/null \
      || "$HOME/.archon/bin/archon" --version 2>/dev/null \
      || command -v archon >/dev/null \
      || { echo "archon not found"; exit 1; }
    ;;
  with-pulumi)
    baseline_check
    pulumi version
    ;;
  with-terraform)
    baseline_check
    terraform --version
    ;;
  with-devcontainer-cli)
    baseline_check
    devcontainer --version
    ;;
  with-devpod)
    baseline_check
    devpod version
    ;;
  *)
    echo "unknown overlay '$name' — running baseline check only" >&2
    baseline_check
    ;;
esac

echo "verify-overlay: $name OK"
