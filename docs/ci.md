# CI

The `.github/workflows/devcontainer.yml` workflow runs on every push to `main` and on every pull request. Two jobs: `drift` then `build`.

## What CI does

### Job 1: `drift` — overlay drift check

```bash
./scripts/check-overlay-drift.sh
```

Regenerates overlays into a temp directory from the current `devcontainer.json` + `*.delta.json` files, then `diff -u` against the committed `*.json` overlays. Any difference fails the job with a message telling you to run `./scripts/build-overlays.sh` locally.

**Why this exists:** overlays are generated files. Without a drift check, the baseline and a committed overlay can drift apart silently — someone edits baseline, forgets to regen, and the overlay ships the old config.

### Job 2: `build` — baseline smoke build

Gated on `drift` passing (`needs: drift`). Uses [`devcontainers/ci@v0.3`](https://github.com/devcontainers/ci) to:

1. Build the baseline devcontainer image.
2. Cache layers into `ghcr.io/<owner>/<repo>/devcontainer` (pulled on subsequent runs for speed).
3. Skip pushing the image (`push: never`) — CI only verifies the build works, not publishes.
4. Run these smoke checks inside the built container:

   ```bash
   claude --version
   gh --version
   git --version
   node --version
   ```

If any of those binaries is missing or broken, CI fails with the specific command's stderr.

## What CI does **not** do

- **Does not build overlays.** Only the baseline is smoke-tested. Overlays are config-only changes; the drift check confirms they match.
- **Does not publish images.** `push: never` is intentional — this is a template, not a source of pre-built images.
- **Does not run your project's tests.** The template ships with a pristine container environment. Add a separate workflow for project tests once you have them.

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

The diff shown in the failing job output tells you exactly which fields drifted.

### Build job failed at "Build devcontainer"

Image build itself broke. Common causes:
- A feature pinned to a version that no longer resolves.
- A network hiccup pulling the base image or a feature layer. **Re-run the job first** — infra flakes aren't rare.
- A syntax error in `devcontainer.json`. Validate locally: `jq -e . .devcontainer/devcontainer.json`.

### Build job failed at a smoke command

Example: `claude: command not found` at the `claude --version` step.

That means `postCreateCommand` (`npm install -g @anthropic-ai/claude-code`) failed during build. Check the logs above the failed step for the npm error. Network issues are common — re-run the job. Persistent failures usually mean either the package moved, or the node feature version changed its npm prefix.

## Running CI checks locally

Before pushing, you can run the full drift check:

```bash
./scripts/check-overlay-drift.sh
```

And a local build (requires the `devcontainer` CLI, installed from npm as `@devcontainers/cli`):

```bash
devcontainer build --workspace-folder .
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . claude --version
```

Or for an overlay:

```bash
devcontainer up --workspace-folder . \
  --override-config .devcontainer/overlays/with-docker-in-docker.json
```

## Extending CI

### Add a job that runs inside the built container

Follow the pattern of the existing `build` job — reuse the `devcontainers/ci@v0.3` action with a different `runCmd`:

```yaml
  my-test:
    runs-on: ubuntu-latest
    needs: drift
    steps:
      - uses: actions/checkout@v4
      - uses: devcontainers/ci@v0.3
        with:
          cacheFrom: ghcr.io/${{ github.repository }}/devcontainer
          push: never
          runCmd: |
            set -eux
            # your commands here
```

### Test an overlay in CI

Add a matrix to `build`, or a sibling job. The devcontainer CI action accepts `configFile`:

```yaml
      - uses: devcontainers/ci@v0.3
        with:
          configFile: .devcontainer/overlays/with-docker-in-docker.json
          push: never
          runCmd: docker --version
```

### Publish the baseline image

Flip `push: never` to `push: always` (plus GHCR login — see the [devcontainers/ci](https://github.com/devcontainers/ci) docs). Only do this if downstream projects actually consume the image; otherwise the template becomes a distribution you now have to maintain.
