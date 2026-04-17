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

Launch with an overlay (use `--override-config`, not `--config` — the CLI rejects filenames other than `devcontainer.json` for `--config`):
```bash
devcontainer up --workspace-folder . --override-config .devcontainer/overlays/with-claude-mount.json
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
