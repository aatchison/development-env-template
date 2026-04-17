# Slash commands

Four Claude Code slash commands ship with the template. They live in `.claude/commands/` and run whenever you type their name in an interactive Claude Code session inside the container.

| Command | When to run | Commits? |
|---|---|:-:|
| `/bootstrap` | Once, right after cloning the template into a new project | optional (asks you) |
| `/add-language` | Any time you need a new language runtime | ❌ leaves staging to you |
| `/verify-env` | Any time you want to sanity-check the container | ❌ |
| `/rebuild-devcontainer` | When you need to rebuild but aren't sure how for your launcher | ❌ explanatory only |

## `/bootstrap`

Interactive first-run setup. Turns the template into a named project.

What it does:

1. Checks `CLAUDE.md` for the seed placeholder. Warns if bootstrap has already run.
2. Asks for:
   - **Project name** — replaces the `name` field in `.devcontainer/devcontainer.json`.
   - **One-line project purpose** — replaces the placeholder line in `CLAUDE.md`.
   - **Languages to add now** — multi-select (python, go, rust, java, ruby, or none). Each selected language is added as a devcontainer feature.
   - **How to run tests** — replaces the testing placeholder in `CLAUDE.md`. Default "Not yet configured." if skipped.
3. Updates `.devcontainer/devcontainer.json` via `jq`.
4. Regenerates overlays if any `*.delta.json` exist.
5. Rewrites `CLAUDE.md` — drops the seed blockquote, substitutes your answers, strips the `<!-- replaced by /bootstrap -->` comments.
6. Offers to `git init` (if needed) and make an initial commit.
7. Reminds you to rebuild the container — try `/rebuild-devcontainer`.

**Run it exactly once.** If you need to reset, edit `CLAUDE.md` and `devcontainer.json` by hand.

## `/add-language`

Adds one official devcontainer language feature to the baseline. Idempotent.

```
/add-language python
/add-language go
/add-language rust
/add-language java
/add-language ruby
```

Feature mapping:

| Argument | Feature key |
|---|---|
| `python` | `ghcr.io/devcontainers/features/python:1` |
| `go` | `ghcr.io/devcontainers/features/go:1` |
| `rust` | `ghcr.io/devcontainers/features/rust:1` |
| `java` | `ghcr.io/devcontainers/features/java:1` |
| `ruby` | `ghcr.io/devcontainers/features/ruby:1` |

Behavior:

- Validates JSON before and after editing.
- If the feature is already present, reports "already present — no change" and exits.
- Adds the feature with default configuration (`{}`). To pass feature options, edit `devcontainer.json` by hand after.
- If overlays exist, regenerates them so overlays inherit the new feature.
- **Does not commit.** You stage and commit yourself.
- After adding a language, rebuild the container to pick it up — try `/rebuild-devcontainer`.

Want a specific Python version or Node with a particular npm? Open `.devcontainer/devcontainer.json` and add options under the feature key:

```json
"ghcr.io/devcontainers/features/python:1": {
  "version": "3.12",
  "installTools": true
}
```

See the [features index](https://containers.dev/features) for each feature's option set.

## `/verify-env`

Probes the container for required tooling and prints a summary. Matches what CI checks for.

Probes:

```bash
claude --version
gh --version
git --version
node --version
```

Environment detection:

```bash
test -f /.dockerenv          # running in a container?
$REMOTE_CONTAINERS            # VS Code Dev Containers
$CODESPACES                   # GitHub Codespaces
$DEVPOD                       # devpod
```

Output is a markdown table — pass/fail per check with the observed version or value. If something fails, it suggests the most likely fix (usually "rebuild the container" or "re-run `postCreateCommand`").

Good to run:

- Right after first build.
- After `/add-language` and a rebuild.
- When something feels off and you want a single-command health check.

## `/rebuild-devcontainer`

**Explanatory only.** Claude runs inside the container and cannot rebuild itself. This command detects your launcher and prints the right instructions.

Detection logic:

- `$REMOTE_CONTAINERS` → VS Code: Command Palette → **Dev Containers: Rebuild Container** (or **…Without Cache** for a clean rebuild).
- `$CODESPACES` → Codespaces menu (bottom-left status bar) → **Rebuild Container**. For a full rebuild from the web UI, use **Full rebuild container**.
- `$DEVPOD` → on the host: `devpod up <workspace-name> --recreate` (add `--reset` to wipe the workspace volume).
- None of the above → prints all three with a note that detection failed.

Running a rebuild terminates the current container session. Save uncommitted work first.

## Adding your own slash commands

Drop a new `.md` file into `.claude/commands/`. The filename (without `.md`) becomes the command name. Required frontmatter:

```markdown
---
description: One-line summary shown in the slash-command picker.
argument-hint: <optional argument hint>
---

# /command-name

Body instructions for Claude.
```

Body content is the instructions Claude follows when the command is invoked. Keep instructions imperative and concrete: what to check, what commands to run, what output to produce.

## Pre-approved permissions

`.claude/settings.json` pre-approves common tools so these commands don't trigger a permission prompt on every step — git read/write ops, `gh` PR viewing, `devcontainer build`/`up`, etc. If you add a command that needs a new capability, add the matching permission there.
