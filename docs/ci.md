# CI

The `.github/workflows/devcontainer.yml` workflow runs on every push to `main` and every pull request. Three jobs: `drift` → `discover` → `build` (matrix).

## What CI does

### Job 1: `drift` — overlay drift check

```bash
./scripts/check-overlay-drift.sh
```

Regenerates overlays into a temp directory from the current `devcontainer.json` + `*.delta.json` files, then `diff -u` against the committed `*.json` overlays. Any difference fails the job with a message telling you to run `./scripts/build-overlays.sh` locally.

**Why this exists:** overlays are generated files. Without a drift check, the baseline and a committed overlay can drift apart silently — someone edits baseline, forgets to regen, and the overlay ships the old config.

### Job 2: `discover` — build the matrix

Lists every overlay in `.devcontainer/overlays/*.json` (plus `baseline`) and emits a JSON matrix for the next job. Adding a new overlay automatically lights up a new CI lane — no workflow edit required.

### Job 3: `build` — matrix per overlay

Gated on `discover`. One job per overlay (plus one for baseline). Each job:

1. Picks the right config file (baseline → `.devcontainer/devcontainer.json`; overlay → `.devcontainer/overlays/<name>.json`).
2. Uses [`devcontainers/ci@v0.3`](https://github.com/devcontainers/ci) to build the container.
3. Caches layers per-overlay into `ghcr.io/<owner>/<repo>/devcontainer-<overlay>` (pulled on subsequent runs — fresh builds are slow, cached builds are fast).
4. Runs `./scripts/verify-overlay.sh <overlay>` **inside** the built container. That script does:
   - Always: `claude --version && gh --version && git --version && node --version` (regression-guards the baseline tools).
   - Plus the overlay-specific check (e.g. `terraform --version` for `with-terraform`).

`fail-fast: false` so one broken overlay doesn't mask failures in others. `push: never` — CI verifies, doesn't publish.

## What CI does **not** do

- **Does not publish images.** `push: never` is intentional.
- **Does not run your project's tests.** Add a separate workflow for project tests once you have them.
- **Does not run interactive login flows.** `claude` is only version-checked, not auth-checked.

## Reading a failure

### Drift job failed

Symptom:
```
DRIFT DETECTED in with-claude-mount.json
Run ./scripts/build-overlays.sh to regenerate overlays.
```

Fix:
```bash
./scripts/build-overlays.sh
git add .devcontainer/overlays/*.json
git commit -m "chore: regenerate overlays"
git push
```

The diff shown in the failing job output tells you which fields drifted.

### A specific overlay build failed

Look at the failed matrix job's name — it's the overlay name. Common causes:

- **Feature no longer resolves.** A pinned feature version was yanked or moved. Check the feature's repo.
- **Network flake.** Feature downloads from GHCR/GitHub/apt. **Re-run the job first.**
- **`postCreateCommand` step failed.** The verify script runs *after* postCreate, so install failures surface here. Look at the action's "Startup" section for the postCreate log.
- **`verify-overlay.sh` exit non-zero.** The tool installed but the check command failed. Could be a binary on `$PATH` mismatch (e.g. installers that put things in `~/.opencode/bin`). Extend the case in `scripts/verify-overlay.sh`.

### Build succeeded but verify failed

Example: `terraform: command not found`. The container built, but the tool isn't on `$PATH` for the user `verify-overlay.sh` runs as. Usually fixed by:
- Using the correct feature version.
- Or extending `verify-overlay.sh` with an alternate path (e.g. `"$HOME/.local/bin/<tool>"`).

## Running the same checks locally

Full drift check:

```bash
./scripts/check-overlay-drift.sh
```

Build + verify a single overlay locally (requires the `devcontainer` CLI, `npm install -g @devcontainers/cli`):

```bash
# baseline
devcontainer up --workspace-folder . --remove-existing-container
devcontainer exec --workspace-folder . ./scripts/verify-overlay.sh baseline

# any overlay
devcontainer up --workspace-folder . \
  --override-config .devcontainer/overlays/with-terraform.json \
  --remove-existing-container
devcontainer exec --workspace-folder . \
  --override-config .devcontainer/overlays/with-terraform.json \
  ./scripts/verify-overlay.sh with-terraform
```

## Adding a new overlay to CI

Two files:

1. Drop your `<name>.delta.json` into `.devcontainer/overlays/` and run `./scripts/build-overlays.sh`. The `discover` job picks it up automatically.
2. Add a `case` for `<name>` in `scripts/verify-overlay.sh` that runs the tool's version check. If you skip this step, CI fails the new lane with `unknown overlay '<name>'` — there is no silent fallback.

No workflow edit needed.

## Extending CI further

### Publish images

Flip `push: never` to `push: always` (plus GHCR login — see the [devcontainers/ci](https://github.com/devcontainers/ci) docs). Only do this if downstream projects actually consume the image; otherwise the template becomes a distribution you now have to maintain.

### Run your project's tests inside the built container

Add a sibling job that reuses the cached image:

```yaml
  project-tests:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: devcontainers/ci@v0.3
        with:
          configFile: .devcontainer/devcontainer.json
          cacheFrom: ghcr.io/${{ github.repository }}/devcontainer-baseline
          push: never
          runCmd: <your test command>
```
