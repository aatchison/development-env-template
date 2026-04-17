# Documentation

User guide for this devcontainer template. Start with the launcher that matches your environment, then branch into overlays or slash commands as needed.

- [Launchers](launchers.md) — run the container in VS Code, Codespaces, devpod (Docker or Kubernetes), or over SSH. Covers `ANTHROPIC_API_KEY` forwarding.
- [Overlays](overlays.md) — optional capabilities layered on top of the baseline (`with-claude-mount`, `with-docker-in-docker`). Also: how overlays are generated, the `--override-config` flag, the drift check, and how to add new overlays.
- [Slash commands](slash-commands.md) — reference for `/bootstrap`, `/add-language`, `/verify-env`, `/rebuild-devcontainer`.
- [CI](ci.md) — what the `devcontainer` GitHub Actions workflow does, how to read failures, how to extend it.

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
.github/workflows/
  devcontainer.yml               # drift check + smoke build
```

## Design spec

The spec and implementation plan are in [`superpowers/`](superpowers/):

- `specs/2026-04-16-devcontainer-template-design.md` — the agreed design.
- `plans/2026-04-16-devcontainer-template.md` — the task-by-task implementation plan.
