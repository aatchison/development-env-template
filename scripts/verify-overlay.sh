#!/usr/bin/env bash
# Verify a built devcontainer has the tools its overlay promises.
# Runs INSIDE the built container. Takes the overlay name (without extension)
# as $1, or "baseline" for the unmodified devcontainer.json.
#
# Exits 0 on success, non-zero on any failed check.
#
# When you add a new overlay, add its case below. Unknown names exit 1 so CI
# fails loudly rather than silently downgrading to baseline-only verification.
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
    # The mount is a launcher concern — the overlay configures the bind but
    # only the host launcher can create the source. CI doesn't have a host
    # ~/.claude, so we allow a missing mount when $CI is set. Locally, a
    # missing mount means the overlay didn't actually do its job, so fail.
    if test -d /home/vscode/.claude; then
      :
    elif [ -n "${CI:-}" ]; then
      echo "warning: ~/.claude not mounted (expected in CI)"
    else
      echo "error: ~/.claude not mounted — overlay's bind mount didn't materialize" >&2
      exit 1
    fi
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
    argocd version --client 2>&1 | sed -n '1,3p'
    ;;
  with-teleport)
    baseline_check
    tsh version 2>&1 | sed -n '1,3p'
    ;;
  with-neovim)
    baseline_check
    nvim --version | sed -n '1p'
    stow --version | sed -n '1p'
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
    # Only accept a working --version call — a binary that exists on $PATH
    # but crashes (missing libs, broken install) shouldn't pass verification.
    archon --version 2>/dev/null \
      || "$HOME/.archon/bin/archon" --version 2>/dev/null \
      || { echo "archon not found or not runnable"; exit 1; }
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
    echo "error: unknown overlay '$name' — add a case in scripts/verify-overlay.sh" >&2
    exit 1
    ;;
esac

echo "verify-overlay: $name OK"
