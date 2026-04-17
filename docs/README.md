# Documentation

User guide for this devcontainer template. Start with the launcher that matches your environment, then branch into overlays or slash commands as needed.

- [Launchers](launchers.md) — run the container in VS Code, Codespaces, devpod (Docker or Kubernetes), or over SSH. Covers `ANTHROPIC_API_KEY` forwarding.
- [Overlays](overlays.md) — optional capabilities layered on top of the baseline (Claude mount, docker-in-docker, language toolchains, CLI tools). Covers how overlays are generated, the `--override-config` flag, the drift check, and how to add new overlays.
- [Slash commands](slash-commands.md) — reference for `/bootstrap`, `/add-language`, `/verify-env`, `/rebuild-devcontainer`.
- [CI](ci.md) — drift check + per-overlay matrix build. How to read failures, how to add a new overlay to CI, how to extend the workflow.

## Where things live

```
.devcontainer/
  devcontainer.json              # baseline
  overlays/
    *.delta.json                 # hand-edited deltas
    *.json                       # generated overlays — do not edit
.claude/
  commands/                      # Claude Code slash commands
  settings.json                  # pre-approved tool permissions
scripts/
  build-overlays.sh              # regenerate overlays from deltas
  check-overlay-drift.sh         # CI drift guard
  verify-overlay.sh              # in-container tool check (CI + local)
.github/workflows/
  devcontainer.yml               # drift check + per-overlay matrix build
```

## Design spec

The spec and implementation plan are in [`superpowers/`](superpowers/):

- `specs/2026-04-16-devcontainer-template-design.md` — the agreed design.
- `plans/2026-04-16-devcontainer-template.md` — the task-by-task implementation plan.
