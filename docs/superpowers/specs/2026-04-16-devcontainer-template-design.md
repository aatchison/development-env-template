# Development Environment Template — Design

**Date:** 2026-04-16
**Author:** arron.atchison@gmail.com (with Claude)
**Status:** Approved — ready for implementation planning

## Purpose

Create a personal template repository that bootstraps new projects with a portable
devcontainer, standard Claude Code conventions, and a CI check that keeps the
devcontainer healthy. The template itself is polyglot: no language runtimes are
baked into the base image. Projects extend it per-project by adding devcontainer
features.

## Goals

- One command (`gh repo create --template …` or VS Code "Clone in Container Volume…")
  gets a working dev loop on VS Code, GitHub Codespaces, and devpod (local Docker or
  Kubernetes provider).
- No reliance on host-filesystem bind mounts in the baseline config, so the template
  works in Codespaces and devpod-on-Kubernetes.
- Claude Code is present in every spawned container, with sane permissions pre-allowed
  and a small set of starter slash commands for new-project setup.

## Non-goals

- Not prescribing language conventions, lint configs, or test frameworks — those come
  per-project.
- Not publishing the template for public/team use. Audience is the author only.
- Not providing a template-update-propagation mechanism. When the template changes,
  downstream projects pull updates manually.

## Repository layout

```
development-env-template/
├── .devcontainer/
│   ├── devcontainer.json                 # portable baseline
│   └── overlays/
│       ├── with-claude-mount.json        # adds ~/.claude bind mount (local Docker only)
│       └── with-docker-in-docker.json    # adds dind feature (needs privileged)
├── .github/
│   └── workflows/
│       └── devcontainer.yml              # builds + smoke-tests the baseline
├── .claude/
│   ├── settings.json                     # project-scoped permissions
│   └── commands/
│       ├── bootstrap.md
│       ├── add-language.md
│       ├── verify-env.md
│       └── rebuild-devcontainer.md
├── .gitignore                            # minimal (node_modules, .env, OS, IDE)
├── CLAUDE.md                             # seed, filled in by /bootstrap
└── README.md                             # usage, auth, overlays, extend-per-project
```

## Devcontainer — baseline

`.devcontainer/devcontainer.json`:

```jsonc
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
    "ghcr.io/devcontainers/features/node:1": { "version": "lts" }
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

Key decisions:

- **Microsoft devcontainer base** (`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`)
  — pre-configured non-root `vscode` user, first-class Codespaces support.
- **Polyglot base:** no Python/Go/Rust by default. `/add-language` adds them per-project.
- **Node present as a dependency, not a language choice** — Claude Code is an npm
  package, so Node LTS is installed as a feature so `postCreateCommand` can
  `npm install -g @anthropic-ai/claude-code`.
- **No bind mounts in the baseline** — Codespaces and devpod-on-k8s can't see the
  host filesystem. `remoteEnv` forwards `ANTHROPIC_API_KEY` from whichever launcher
  is running (local env, Codespaces secret, devpod secret).
- **`docker-in-docker` is not in the baseline.** It needs a privileged pod, which is
  cluster-dependent. Available as an overlay for local Docker users.
- **Default shell is bash.** `common-utils` installs zsh too, but does not set it as
  default.

## Devcontainer — overlays

The devcontainer spec does not define config inheritance, so each overlay is a
**standalone** `devcontainer.json` that duplicates the baseline's core fields
(`image`, `remoteUser`, `features`, `customizations`, `remoteEnv`) and adds its
delta. Users pick an overlay at launch time:

```
devcontainer up --config .devcontainer/overlays/with-claude-mount.json
```

To keep overlays from drifting from the baseline, the implementation plan should
either (a) generate overlays from the baseline via a small script, or (b) add a CI
check that diffs shared fields. Leaving that choice to implementation.

**`with-claude-mount.json`** — baseline + a `mounts` entry:
`source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached`.
Usable only where the launcher can see the host FS (local Docker / devpod-local).

**`with-docker-in-docker.json`** — baseline + the
`ghcr.io/devcontainers/features/docker-in-docker:2` feature. Usable only where the
runtime permits privileged containers.

Overlays are composable by convention: a user wanting both creates a one-off combined
config locally. We don't ship a pre-combined variant.

## Claude conventions

**`.claude/settings.json`** — project-scoped permissions only. No hooks in the seed;
those get added per-project.

```jsonc
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

Rationale: pre-approves the read-only and low-risk ops hit on every project.
Destructive ops (`rm`, `git push --force`, `git reset --hard`) stay unlisted so they
always prompt.

**`CLAUDE.md`** — short seed, ~20 lines:

- Project purpose (placeholder filled by `/bootstrap`).
- Environment: "Development happens in the devcontainer defined in `.devcontainer/`.
  Run `devcontainer up` or open in VS Code / Codespaces."
- Conventions: "Match existing patterns. No speculative abstractions. No comments
  that restate code."
- Testing / verification: placeholder filled per-project.
- Commands: empty markdown table, filled per-project.

## Starter slash commands

All four live in `.claude/commands/` as `.md` files.

### `/bootstrap`
Runs once after cloning the template. Interactively:
1. Ask project name and one-line purpose.
2. Ask which language features to add now (multi-select: python, go, rust, java,
   ruby, none).
3. Write `CLAUDE.md` placeholder substitutions.
4. Edit `.devcontainer/devcontainer.json`'s `features` block to include the chosen
   language features.
5. Optionally `git init` and make an initial commit (ask first).
6. Remind user to rebuild the container if already running.

### `/add-language`
Add one language feature to the baseline `devcontainer.json` after project creation.
Accepts an arg (`/add-language python`) or prompts if missing. Mapping:

| Argument | Feature |
|----------|---------|
| `python` | `ghcr.io/devcontainers/features/python:1` |
| `go`     | `ghcr.io/devcontainers/features/go:1` |
| `rust`   | `ghcr.io/devcontainers/features/rust:1` |
| `java`   | `ghcr.io/devcontainers/features/java:1` |
| `ruby`   | `ghcr.io/devcontainers/features/ruby:1` |

Idempotent: no-op if the feature is already present. Ends with: "Rebuild the
container to pick this up — try `/rebuild-devcontainer`."

### `/verify-env`
Runs the same probes as the CI workflow plus a couple of environment checks:

- `claude --version`
- `gh --version`
- `git --version`
- `node --version`
- Devcontainer detection: presence of `/.dockerenv` AND any of
  `$REMOTE_CONTAINERS`, `$CODESPACES`, `$DEVPOD` being set.

Reports a per-check pass/fail table. Exits clean even if some fail — the user wants a
diagnosis, not an abort.

### `/rebuild-devcontainer`
Purely explanatory — Claude runs inside the container, so it cannot trigger its own
rebuild. Detects the environment via env vars (`$CODESPACES`, `$REMOTE_CONTAINERS`,
`$DEVPOD`) and prints the matching instructions:

- VS Code: "Command palette → Dev Containers: Rebuild Container"
- Codespaces: "Codespaces menu → Rebuild Container"
- devpod: "On host: `devpod up <workspace> --recreate`"
- Unknown: show all three.

## CI

`.github/workflows/devcontainer.yml` builds the baseline devcontainer on every push
to `main` and every pull request, then runs smoke commands inside it.

```yaml
name: devcontainer
on:
  push: { branches: [main] }
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          cacheFrom: ghcr.io/${{ github.repository }}/devcontainer
          push: never
          runCmd: |
            claude --version
            gh --version
            git --version
            node --version
```

- `push: never` — build-only, no image published. Flip to `filterOnly` later to
  publish prebuilt images for Codespaces speed-up.
- Overlays are not verified in CI. They're optional and add time; can be added as a
  matrix job if they start drifting.

## README

Top-level sections:

1. **What this is.** One-paragraph pitch: portable devcontainer baseline for the
   author's projects.
2. **Quickstart.**
   - VS Code: "Dev Containers: Clone Repository in Container Volume…"
   - Codespaces: "Create codespace on main"
   - devpod (local Docker): `devpod up .`
   - devpod (Kubernetes): `devpod up . --provider kubernetes`
3. **Auth.** Set `ANTHROPIC_API_KEY` (Codespaces secret / devpod secret / local
   env), or run `claude login` on first shell.
4. **Overlays.** When and how to use `with-claude-mount.json` and
   `with-docker-in-docker.json`; note k8s limitations for dind and local-only nature
   of the mount.
5. **Extending per-project.** "Run `/add-language <lang>` or edit
   `.devcontainer/devcontainer.json`'s `features` block directly, then rebuild."
6. **Updating the template.** One-liner: downstream projects pull changes manually;
   no automated sync scoped here.

## Out of scope

- Publishing prebuilt images to GHCR.
- Matrix CI that verifies overlays.
- Language-specific tooling (linters, formatters, test harnesses) in the base.
- License, CONTRIBUTING, CODE_OF_CONDUCT (personal template, not public).
- `.editorconfig` (may be added per-project as language needs become clearer).

## Portability contract

| Environment        | Baseline works? | `with-claude-mount`? | `with-docker-in-docker`? |
|--------------------|:---------------:|:--------------------:|:------------------------:|
| VS Code + Docker Desktop | ✅ | ✅ | ✅ |
| GitHub Codespaces        | ✅ | ❌ (no host FS)   | ❌ (no privileged) |
| devpod + Docker          | ✅ | ✅ | ✅ |
| devpod + Kubernetes      | ✅ | ❌ (no host FS)   | ⚠️ (cluster-dependent) |
| Neovim / terminal via SSH | ✅ | ✅ if launcher has host FS | depends on runtime |

## Open questions

None at spec-approval time.
