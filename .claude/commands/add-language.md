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
