# Devcontainer Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal devcontainer template repo producing a portable Ubuntu-based dev environment, Claude Code preinstalled, working on VS Code, Codespaces, and devpod (including Kubernetes provider), with starter Claude slash commands, CI smoke-test, and DRY overlay generator.

**Architecture:** Single baseline `devcontainer.json` with zero host-FS assumptions. Two overlays (`with-claude-mount`, `with-docker-in-docker`) are **generated** from baseline + small delta files via a `jq`-based script so shared fields never drift. CI rebuilds baseline and verifies no overlay drift on every push.

**Tech Stack:** Docker, devcontainer spec (Microsoft Ubuntu base image + official features), GitHub Actions, `jq`, Bash, Markdown.

**Spec:** `docs/superpowers/specs/2026-04-16-devcontainer-template-design.md`

**Working directory:** `/home/aatchison/src/aatchison/development-env-template` (already a git repo; `main` branch contains the committed spec).

**Global prerequisites (verify before starting Task 1):**
- `docker` daemon running
- `jq` ≥ 1.6 on PATH
- `node` + `npm` on PATH (used to run `@devcontainers/cli` via `npx`)
- `python3` on PATH (used for YAML validation)

Quick check:
```bash
docker info >/dev/null && jq --version && node --version && python3 --version
```

---

## File Structure

```
.gitignore
.devcontainer/
├── devcontainer.json                              # baseline (Task 2)
└── overlays/
    ├── with-claude-mount.delta.json               # source delta (Task 4)
    ├── with-claude-mount.json                     # generated (Task 4)
    ├── with-docker-in-docker.delta.json           # source delta (Task 4)
    └── with-docker-in-docker.json                 # generated (Task 4)
scripts/
├── build-overlays.sh                              # generator (Task 4)
└── check-overlay-drift.sh                         # CI drift check (Task 5)
.github/
└── workflows/
    └── devcontainer.yml                           # CI (Task 3, extended in Task 5)
.claude/
├── settings.json                                  # Task 6
└── commands/
    ├── verify-env.md                              # Task 8
    ├── rebuild-devcontainer.md                    # Task 9
    ├── add-language.md                            # Task 10
    └── bootstrap.md                               # Task 11
CLAUDE.md                                          # Task 7
README.md                                          # Task 12
```

Responsibilities:
- `.devcontainer/devcontainer.json` — the only runtime config most environments consume.
- `*.delta.json` — minimal overlay-specific additions; source of truth for overlays.
- `*.json` (non-delta overlays) — generated; committed so launchers don't need to run the script.
- `scripts/build-overlays.sh` — single writer of overlay files; produces deterministic output.
- `scripts/check-overlay-drift.sh` — regenerates to temp dir, diffs, fails on mismatch.
- `.claude/commands/*.md` — slash command prompts, each one standalone.

---

## Task 1: `.gitignore`

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# OS
.DS_Store
Thumbs.db

# Editors / IDE
.idea/
.vscode/*
!.vscode/extensions.json
*.swp
*.swo

# Node
node_modules/

# Python
__pycache__/
*.pyc
.venv/
venv/

# Environment / secrets
.env
.env.local
*.pem

# Build / temp
dist/
build/
*.log
.tmp/
```

- [ ] **Step 2: Verify the file exists**

Run:
```bash
test -s .gitignore && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add minimal .gitignore"
```

---

## Task 2: Baseline `devcontainer.json`

**Files:**
- Create: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Create the `.devcontainer` directory**

Run:
```bash
mkdir -p .devcontainer
```

- [ ] **Step 2: Write `.devcontainer/devcontainer.json` (pure JSON, no comments)**

```json
{
  "name": "development-env-template",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "configureZshAsDefaultShell": false,
      "username": "vscode"
    },
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/node:1": {
      "version": "lts"
    }
  },
  "postCreateCommand": "npm install -g @anthropic-ai/claude-code",
  "remoteUser": "vscode",
  "remoteEnv": {
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "ms-azuretools.vscode-docker",
        "github.vscode-github-actions",
        "editorconfig.editorconfig"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  }
}
```

- [ ] **Step 3: Validate it is syntactically valid JSON**

Run:
```bash
jq -e . .devcontainer/devcontainer.json >/dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 4: Validate it parses as a devcontainer configuration**

Run:
```bash
npx -y @devcontainers/cli@latest read-configuration --workspace-folder . | jq -e '.configuration.name == "development-env-template"' >/dev/null && echo OK
```
Expected: `OK`

(If `npx` is not permitted offline, skip this step and rely on Task 13's end-to-end build.)

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add baseline devcontainer.json"
```

---

## Task 3: CI workflow (baseline build)

**Files:**
- Create: `.github/workflows/devcontainer.yml`

- [ ] **Step 1: Create the workflow directory**

Run:
```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write `.github/workflows/devcontainer.yml`**

```yaml
name: devcontainer
on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    name: build baseline
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build devcontainer and run smoke checks
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          cacheFrom: ghcr.io/${{ github.repository }}/devcontainer
          push: never
          runCmd: |
            set -eux
            claude --version
            gh --version
            git --version
            node --version
```

- [ ] **Step 3: Validate YAML syntax**

Run:
```bash
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/devcontainer.yml')); print('OK')"
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/devcontainer.yml
git commit -m "ci: build devcontainer and smoke-check installed tools"
```

---

## Task 4: Overlay generator + overlays

**Files:**
- Create: `scripts/build-overlays.sh`
- Create: `.devcontainer/overlays/with-claude-mount.delta.json`
- Create: `.devcontainer/overlays/with-docker-in-docker.delta.json`
- Generate: `.devcontainer/overlays/with-claude-mount.json`
- Generate: `.devcontainer/overlays/with-docker-in-docker.json`

- [ ] **Step 1: Create directories**

Run:
```bash
mkdir -p .devcontainer/overlays scripts
```

- [ ] **Step 2: Write `scripts/build-overlays.sh`**

```bash
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
```

- [ ] **Step 3: Make the script executable**

Run:
```bash
chmod +x scripts/build-overlays.sh
```

- [ ] **Step 4: Write `.devcontainer/overlays/with-claude-mount.delta.json`**

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached"
  ]
}
```

- [ ] **Step 5: Write `.devcontainer/overlays/with-docker-in-docker.delta.json`**

```json
{
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  }
}
```

- [ ] **Step 6: Run the generator**

Run:
```bash
./scripts/build-overlays.sh
```
Expected output includes:
```
wrote .devcontainer/overlays/with-claude-mount.json
wrote .devcontainer/overlays/with-docker-in-docker.json
```

- [ ] **Step 7: Validate generated overlays are valid JSON**

Run:
```bash
for f in .devcontainer/overlays/with-*.json; do
  [[ "$f" == *.delta.json ]] && continue
  jq -e . "$f" >/dev/null
done && echo OK
```
Expected: `OK`

- [ ] **Step 8: Verify `with-claude-mount.json` preserves baseline and adds mount**

Run:
```bash
jq -e '
  .image == "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"
  and (.mounts | length) == 1
  and (.mounts[0] | test("source=\\${localEnv:HOME}/\\.claude"))
  and (.features | has("ghcr.io/devcontainers/features/node:1"))
' .devcontainer/overlays/with-claude-mount.json >/dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 9: Verify `with-docker-in-docker.json` preserves baseline and adds dind feature**

Run:
```bash
jq -e '
  .image == "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"
  and (.features | has("ghcr.io/devcontainers/features/docker-in-docker:2"))
  and (.features | has("ghcr.io/devcontainers/features/node:1"))
' .devcontainer/overlays/with-docker-in-docker.json >/dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 10: Commit**

```bash
git add scripts/build-overlays.sh .devcontainer/overlays/
git commit -m "feat: generate overlays from baseline + delta files"
```

---

## Task 5: Overlay drift check (+ CI integration)

**Files:**
- Create: `scripts/check-overlay-drift.sh`
- Modify: `.github/workflows/devcontainer.yml` (add a `drift` job)

- [ ] **Step 1: Write `scripts/check-overlay-drift.sh`**

```bash
#!/usr/bin/env bash
# Regenerate overlays into a temp dir and diff against committed copies.
# Exits non-zero if any overlay differs (indicating drift).
set -euo pipefail

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
```

- [ ] **Step 2: Make the script executable**

Run:
```bash
chmod +x scripts/check-overlay-drift.sh
```

- [ ] **Step 3: Run the drift check locally — should pass immediately after Task 4**

Run:
```bash
./scripts/check-overlay-drift.sh
```
Expected: `No overlay drift.`

- [ ] **Step 4: Confirm the check FAILS when overlays are tampered with**

Run:
```bash
cp .devcontainer/overlays/with-claude-mount.json /tmp/claude-mount-backup.json
jq '.name = "tampered"' .devcontainer/overlays/with-claude-mount.json > /tmp/tampered && mv /tmp/tampered .devcontainer/overlays/with-claude-mount.json
./scripts/check-overlay-drift.sh; rc=$?
cp /tmp/claude-mount-backup.json .devcontainer/overlays/with-claude-mount.json
test $rc -ne 0 && echo "drift check correctly failed"
```
Expected: `drift check correctly failed` (preceded by a diff).

- [ ] **Step 5: Extend `.github/workflows/devcontainer.yml` with a drift job**

Replace the file contents with:

```yaml
name: devcontainer
on:
  push:
    branches: [main]
  pull_request:

jobs:
  drift:
    name: overlay drift check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check overlay drift
        run: ./scripts/check-overlay-drift.sh

  build:
    name: build baseline
    runs-on: ubuntu-latest
    needs: drift
    steps:
      - uses: actions/checkout@v4
      - name: Build devcontainer and run smoke checks
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          cacheFrom: ghcr.io/${{ github.repository }}/devcontainer
          push: never
          runCmd: |
            set -eux
            claude --version
            gh --version
            git --version
            node --version
```

- [ ] **Step 6: Validate YAML**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/devcontainer.yml')); print('OK')"
```
Expected: `OK`

- [ ] **Step 7: Commit**

```bash
git add scripts/check-overlay-drift.sh .github/workflows/devcontainer.yml
git commit -m "ci: fail on overlay drift from baseline"
```

---

## Task 6: `.claude/settings.json`

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Create the directory**

Run:
```bash
mkdir -p .claude
```

- [ ] **Step 2: Write `.claude/settings.json`**

```json
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(gh run view:*)",
      "Bash(devcontainer build:*)",
      "Bash(devcontainer up:*)"
    ]
  }
}
```

- [ ] **Step 3: Validate JSON**

Run:
```bash
jq -e '.permissions.allow | type == "array" and length >= 10' .claude/settings.json >/dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -m "chore: seed .claude/settings.json with low-risk allow list"
```

---

## Task 7: `CLAUDE.md` seed

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
# CLAUDE.md

> Seed file. Run the `/bootstrap` slash command on first use to replace placeholders.

## Project purpose

_One line describing what this project does._ <!-- replaced by /bootstrap -->

## Environment

Development happens in the devcontainer defined in `.devcontainer/`.

- VS Code: "Dev Containers: Clone Repository in Container Volume…"
- Codespaces: "Create codespace on main"
- devpod: `devpod up .`

Auth: set `ANTHROPIC_API_KEY` in your launcher's secret store, or run `claude login`
on first shell.

## Conventions

- Match existing patterns. Don't introduce abstractions that aren't earned.
- No comments that restate code. Comments explain *why*, not *what*.
- Small, focused files over large ones that do too much.

## Testing

_Fill in how to run tests once the project has them._ <!-- replaced by /bootstrap -->

## Commands

| Command | Purpose |
|---------|---------|
| _(none yet)_ | _(filled in as the project grows)_ |
```

- [ ] **Step 2: Verify file exists and contains placeholders the `/bootstrap` command will target**

Run:
```bash
grep -q "replaced by /bootstrap" CLAUDE.md && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md seed"
```

---

## Task 8: `.claude/commands/verify-env.md`

**Files:**
- Create: `.claude/commands/verify-env.md`

- [ ] **Step 1: Create the directory**

Run:
```bash
mkdir -p .claude/commands
```

- [ ] **Step 2: Write `.claude/commands/verify-env.md`**

````markdown
---
description: Verify the devcontainer environment is healthy (claude, gh, git, node, plus container detection).
---

# /verify-env

Run the same tool-presence probes the CI workflow runs, plus environment detection.

## Steps

1. Run each command below via the Bash tool. Capture the output (or the error) for each. Do not abort on a single failure — report all results together.

   ```bash
   claude --version
   gh --version
   git --version
   node --version
   ```

2. Detect the runtime environment by checking:
   - `/.dockerenv` exists → running inside a container.
   - `$REMOTE_CONTAINERS` set → VS Code Dev Containers.
   - `$CODESPACES` set → GitHub Codespaces.
   - `$DEVPOD` set → devpod.

   ```bash
   test -f /.dockerenv && echo "container: yes" || echo "container: no"
   echo "REMOTE_CONTAINERS=${REMOTE_CONTAINERS:-unset}"
   echo "CODESPACES=${CODESPACES:-unset}"
   echo "DEVPOD=${DEVPOD:-unset}"
   ```

3. Present a markdown table summarizing each check as `pass` or `fail` with the observed version / value. Example:

   | Check | Status | Detail |
   |-------|--------|--------|
   | claude | pass | 1.2.3 |
   | gh | pass | 2.40.0 |
   | container | pass | /.dockerenv present |

4. If anything fails, note which environment the user is in (per step 2) and suggest the most likely cause — usually "rebuild the container" or "re-run postCreateCommand".
````

- [ ] **Step 3: Verify command loads (basic sanity — file has a frontmatter `description` field)**

Run:
```bash
head -5 .claude/commands/verify-env.md | grep -q "^description:" && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/verify-env.md
git commit -m "feat(claude): add /verify-env slash command"
```

---

## Task 9: `.claude/commands/rebuild-devcontainer.md`

**Files:**
- Create: `.claude/commands/rebuild-devcontainer.md`

- [ ] **Step 1: Write `.claude/commands/rebuild-devcontainer.md`**

````markdown
---
description: Explain how to rebuild the devcontainer (Claude runs inside it and cannot rebuild itself).
---

# /rebuild-devcontainer

You are running **inside** the devcontainer you are being asked about. You cannot rebuild it. This command produces the right instructions for the user's launcher.

## Steps

1. Detect the launcher via env vars:

   ```bash
   echo "REMOTE_CONTAINERS=${REMOTE_CONTAINERS:-unset}"
   echo "CODESPACES=${CODESPACES:-unset}"
   echo "DEVPOD=${DEVPOD:-unset}"
   ```

2. Map the detection to instructions:

   - `$REMOTE_CONTAINERS` set → VS Code Dev Containers: "Open the Command Palette and run **Dev Containers: Rebuild Container**. To fully discard cached layers use **Dev Containers: Rebuild Container Without Cache**."
   - `$CODESPACES` set → GitHub Codespaces: "Open the Codespaces menu (bottom-left status bar) and select **Rebuild Container**. For a clean rebuild, use the GitHub web UI: … → `Full rebuild container`."
   - `$DEVPOD` set → devpod: "On your host (not inside the container), run `devpod up <workspace-name> --recreate`. Add `--reset` to discard the workspace volume."
   - None set → print all three with a note that the launcher could not be determined.

3. Remind the user: "Rebuilding exits this container session. Save any uncommitted work first."

4. Do NOT attempt any rebuild action yourself — this command is explanatory only.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/rebuild-devcontainer.md
git commit -m "feat(claude): add /rebuild-devcontainer slash command"
```

---

## Task 10: `.claude/commands/add-language.md`

**Files:**
- Create: `.claude/commands/add-language.md`

- [ ] **Step 1: Write `.claude/commands/add-language.md`**

````markdown
---
description: Add a language feature (python, go, rust, java, ruby) to .devcontainer/devcontainer.json.
argument-hint: <python|go|rust|java|ruby>
---

# /add-language

Add one official devcontainer language feature to the baseline `.devcontainer/devcontainer.json`. Idempotent — if the feature is already present, report and exit.

## Feature mapping

| Argument | Feature key |
|----------|-------------|
| `python` | `ghcr.io/devcontainers/features/python:1` |
| `go`     | `ghcr.io/devcontainers/features/go:1` |
| `rust`   | `ghcr.io/devcontainers/features/rust:1` |
| `java`   | `ghcr.io/devcontainers/features/java:1` |
| `ruby`   | `ghcr.io/devcontainers/features/ruby:1` |

## Steps

1. Read the user's argument. If missing or not in the table above, ask via `AskUserQuestion` with the five options and proceed with the answer.

2. Read `.devcontainer/devcontainer.json`. Verify it parses as JSON:

   ```bash
   jq -e . .devcontainer/devcontainer.json >/dev/null
   ```

3. Check whether the chosen feature key already exists:

   ```bash
   jq --arg k "<feature-key>" -e '.features | has($k)' .devcontainer/devcontainer.json
   ```

   If it exits `0` (feature present), tell the user "already present — no change" and stop.

4. Add the feature with default configuration. Use `jq` to produce the new file:

   ```bash
   jq --arg k "<feature-key>" '.features[$k] = {}' .devcontainer/devcontainer.json > .devcontainer/devcontainer.json.new
   mv .devcontainer/devcontainer.json.new .devcontainer/devcontainer.json
   ```

5. Re-validate:

   ```bash
   jq -e . .devcontainer/devcontainer.json >/dev/null
   ```

6. If overlays exist (`ls .devcontainer/overlays/*.delta.json 2>/dev/null`), regenerate them so they inherit the new feature:

   ```bash
   ./scripts/build-overlays.sh
   ```

7. Report: "Added `<feature-key>`. Rebuild the container to pick this up — try `/rebuild-devcontainer`."

8. Do NOT commit — leave staging to the user.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/add-language.md
git commit -m "feat(claude): add /add-language slash command"
```

---

## Task 11: `.claude/commands/bootstrap.md`

**Files:**
- Create: `.claude/commands/bootstrap.md`

- [ ] **Step 1: Write `.claude/commands/bootstrap.md`**

````markdown
---
description: First-run setup after cloning this template — fills CLAUDE.md and adds language features.
---

# /bootstrap

Run once after creating a new project from this template. Interactive — do not skip confirmation prompts.

## Steps

1. Confirm this is a fresh bootstrap by checking whether `CLAUDE.md` still contains the seed placeholder:

   ```bash
   grep -q "replaced by /bootstrap" CLAUDE.md
   ```

   If the grep returns non-zero (placeholder already replaced), warn the user: "Looks like bootstrap already ran. Continue anyway?" and require an explicit yes before proceeding.

2. Ask the user for:
   - **Project name** (free text — used as the devcontainer `name`).
   - **One-line project purpose** (free text — replaces the project-purpose placeholder in `CLAUDE.md`).
   - **Languages to add now** (multi-select via `AskUserQuestion`: python, go, rust, java, ruby, none).
   - **How to run tests** (free text — replaces the testing placeholder in `CLAUDE.md`. Offer a default of "Not yet configured." if the user skips.).

3. Update `.devcontainer/devcontainer.json` `name` field:

   ```bash
   jq --arg n "<project-name>" '.name = $n' .devcontainer/devcontainer.json > .tmp.json && mv .tmp.json .devcontainer/devcontainer.json
   ```

4. For each selected language, run the `/add-language` logic (mapping in that file). Do this by directly editing `devcontainer.json` with `jq` — do not recursively invoke `/add-language`.

5. Regenerate overlays if deltas exist:

   ```bash
   [ -d .devcontainer/overlays ] && ./scripts/build-overlays.sh
   ```

6. Update `CLAUDE.md`:
   - Replace the line starting `_One line describing what this project does._` with the user's project purpose. Remove the trailing `<!-- replaced by /bootstrap -->` comment.
   - Replace the line starting `_Fill in how to run tests once the project has them._` with the user's testing answer. Remove the trailing comment.
   - Remove the top "> Seed file…" blockquote.

7. Ask whether to `git init` (if not already a repo) and make an initial commit. If the user agrees:

   ```bash
   git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init -q -b main
   git add .
   git commit -q -m "chore: bootstrap project from devcontainer template"
   ```

8. Print a short summary of changes made and remind the user to rebuild the container if it's already running — try `/rebuild-devcontainer`.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/bootstrap.md
git commit -m "feat(claude): add /bootstrap slash command"
```

---

## Task 12: `README.md`

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# development-env-template

Personal, portable devcontainer template for new projects. Works across VS Code Dev Containers, GitHub Codespaces, and devpod (local Docker or Kubernetes provider). Polyglot base — no language runtimes are installed by default. Extend per-project.

## Quickstart

Pick your launcher:

- **VS Code:** "Dev Containers: Clone Repository in Container Volume…" and paste the repo URL.
- **GitHub Codespaces:** "Code → Codespaces → Create codespace on main".
- **devpod (local Docker):** `devpod up .`
- **devpod (Kubernetes):** `devpod up . --provider kubernetes`

After first shell, run `/bootstrap` in Claude Code to fill in project metadata and add language features.

## Auth

The devcontainer forwards `ANTHROPIC_API_KEY` from the launcher. Set it as:

- Local shell: `export ANTHROPIC_API_KEY=…`
- Codespaces: repository/codespaces secret named `ANTHROPIC_API_KEY`.
- devpod: `devpod up . --set-env ANTHROPIC_API_KEY=…` or configured at provider level.

Alternative: run `claude login` inside the container on first use.

## Overlays

Overlays add capabilities the baseline can't ship by default:

- **`.devcontainer/overlays/with-claude-mount.json`** — bind-mounts `~/.claude` into the container so your local Claude credentials carry in. **Local Docker / devpod-Docker only** — Codespaces and devpod-Kubernetes can't see the host filesystem.
- **`.devcontainer/overlays/with-docker-in-docker.json`** — adds the docker-in-docker feature. Requires a privileged container. Works on local Docker; may be refused on devpod-Kubernetes (cluster-dependent); not supported in Codespaces.

Launch with an overlay:
```bash
devcontainer up --workspace-folder . --config .devcontainer/overlays/with-claude-mount.json
```

Overlays are generated from `*.delta.json` files by `scripts/build-overlays.sh`. Edit the baseline or a delta, then re-run the script — never hand-edit the generated overlay files. CI fails on drift.

## Extending per-project

- Add a language: run `/add-language <python|go|rust|java|ruby>` in Claude Code, or edit `.devcontainer/devcontainer.json`'s `features` block directly.
- Rebuild the container afterward — see `/rebuild-devcontainer` for the right command in your launcher.
- Claude slash commands (`.claude/commands/`):
  - `/bootstrap` — first-run setup.
  - `/add-language` — add one language feature.
  - `/verify-env` — probe installed tools.
  - `/rebuild-devcontainer` — print rebuild instructions for your launcher.

## Updating from the template

No automated sync. When the template changes, pull relevant files (baseline, overlays, CI, slash commands) into downstream projects manually.

## Environment matrix

| Environment              | Baseline | with-claude-mount | with-docker-in-docker |
|--------------------------|:--------:|:-----------------:|:---------------------:|
| VS Code + Docker Desktop |    ✅    |        ✅         |          ✅           |
| GitHub Codespaces        |    ✅    |        ❌         |          ❌           |
| devpod + Docker          |    ✅    |        ✅         |          ✅           |
| devpod + Kubernetes      |    ✅    |        ❌         |         ⚠️           |
| Neovim / SSH to container|    ✅    |   if host FS ok   |    depends on runtime |
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with quickstart, overlays, and env matrix"
```

---

## Task 13: End-to-end verification

No files — this task runs the whole thing and confirms it works. If any step fails, fix the referenced file, re-run the failing step, and commit the fix before moving on.

- [ ] **Step 1: Validate every JSON file in the repo**

Run:
```bash
find .devcontainer .claude -name '*.json' -print0 | xargs -0 -I{} sh -c 'jq -e . "{}" >/dev/null && echo "ok {}"'
```
Expected: one `ok <path>` line per file, no errors.

- [ ] **Step 2: Regenerate overlays and verify no drift**

Run:
```bash
./scripts/build-overlays.sh
./scripts/check-overlay-drift.sh
```
Expected: `No overlay drift.`

- [ ] **Step 3: Build the baseline devcontainer locally**

Run:
```bash
npx -y @devcontainers/cli@latest up --workspace-folder .
```
Expected: command exits 0. A container is created. Note the container id from the final JSON output.

- [ ] **Step 4: Verify tools are installed inside the container**

Run:
```bash
npx -y @devcontainers/cli@latest exec --workspace-folder . bash -lc 'set -eux; claude --version; gh --version; git --version; node --version'
```
Expected: all four version commands print non-empty output, exit 0.

- [ ] **Step 5: Tear down the test container**

Run:
```bash
docker ps --filter "label=devcontainer.local_folder=$PWD" --format '{{.ID}}' | xargs -r docker rm -f
```
Expected: container id(s) printed as removed, or no output if already stopped.

- [ ] **Step 6: Smoke-test the `with-docker-in-docker` overlay locally**

Run:
```bash
npx -y @devcontainers/cli@latest up --workspace-folder . --config .devcontainer/overlays/with-docker-in-docker.json
npx -y @devcontainers/cli@latest exec --workspace-folder . --config .devcontainer/overlays/with-docker-in-docker.json bash -lc 'docker --version'
docker ps --filter "label=devcontainer.local_folder=$PWD" --format '{{.ID}}' | xargs -r docker rm -f
```
Expected: `docker --version` prints a version string inside the overlay container.

(`with-claude-mount` is not smoke-tested here since it requires `~/.claude` to exist, which is environment-dependent; it's exercised by any future local use.)

- [ ] **Step 7: Final repo sanity check**

Run:
```bash
git status
git log --oneline
```
Expected: working tree clean; log shows one commit per completed task plus the earlier spec commit.

- [ ] **Step 8: Push and confirm CI passes**

Run:
```bash
git push -u origin main
```
Then open the Actions tab on GitHub (or `gh run list --limit 1 --json status,conclusion`) and confirm both `drift` and `build` jobs succeed.

Expected: both jobs green.

---

## Self-review notes

- **Spec coverage:** every Goals/Files item is covered — baseline (Task 2), overlays (Task 4), CI (Tasks 3, 5), settings (Task 6), CLAUDE.md (Task 7), commands (Tasks 8–11), README (Task 12). Open choice in spec §"Devcontainer — overlays" (generator vs diff) is resolved by doing both.
- **Placeholders:** none — each step has code or a command.
- **Type consistency:** feature keys match between spec, baseline, overlays, and `/add-language`; env var names (`ANTHROPIC_API_KEY`, `REMOTE_CONTAINERS`, `CODESPACES`, `DEVPOD`) are consistent across slash commands, README, and devcontainer.json.
