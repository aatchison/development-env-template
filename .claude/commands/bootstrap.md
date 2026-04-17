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
