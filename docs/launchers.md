# Launchers

Pick the launcher that matches your environment. All four read the same `.devcontainer/devcontainer.json` and end up with the same tooling inside (`claude`, `gh`, `git`, `node`).

| Launcher | Host filesystem visible to container | Privileged containers | Forwards `ANTHROPIC_API_KEY` |
|---|:-:|:-:|:-:|
| VS Code + Docker Desktop | ✅ | ✅ | via `localEnv` |
| GitHub Codespaces | ❌ | ❌ | via repo/codespaces secret |
| devpod + Docker | ✅ | ✅ | via `--set-env` |
| devpod + Kubernetes | ❌ | ⚠️ cluster-dependent | via `--set-env` |
| SSH / Neovim into running container | n/a | n/a | inherited from launcher that started the container |

## VS Code + Docker Desktop

1. Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).
2. Either:
   - Open the repo locally and run **Dev Containers: Reopen in Container** from the Command Palette, or
   - Run **Dev Containers: Clone Repository in Container Volume…** and paste the repo URL (keeps host fs out of the container — good for laptop-cleanliness).
3. Watch the "Dev Containers" output pane. First build takes a few minutes; subsequent opens use cached layers.
4. After it finishes, open a terminal inside VS Code and run `/verify-env` in Claude Code to confirm tools are healthy.

`ANTHROPIC_API_KEY`: exported in your host shell (`export ANTHROPIC_API_KEY=…` in `~/.bashrc` or `~/.zshrc`) is picked up via `remoteEnv` in `devcontainer.json`.

## GitHub Codespaces

1. On the repo page: **Code → Codespaces → Create codespace on main**.
2. Wait for the codespace to build and open. You land in a browser VS Code by default; to use a desktop client, install the **GitHub Codespaces** extension and connect.
3. Claude Code is preinstalled by `postCreateCommand`. First-run auth works one of two ways:
   - **Repo or codespaces secret** named `ANTHROPIC_API_KEY` — set at https://github.com/settings/codespaces or in repo settings. Automatically injected.
   - **Login flow:** run `claude login` inside the codespace terminal on first use.

Codespaces cannot see the host filesystem, so the `with-claude-mount` overlay does not apply here.

## devpod + Docker (local)

```bash
devpod up .
```

`ANTHROPIC_API_KEY` forwarding:

```bash
devpod up . --set-env ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
```

Or configure at the provider level with `devpod provider set-options docker` so you don't have to pass `--set-env` every time.

Launch with an overlay (see [overlays](overlays.md)):

```bash
devpod up . --devcontainer-path .devcontainer/overlays/with-claude-mount.json
```

(devpod accepts alternative devcontainer paths directly; the VS Code/`devcontainer` CLI equivalent uses `--override-config`.)

## devpod + Kubernetes

```bash
devpod up . --provider kubernetes
```

Two constraints to know:

- **No host filesystem.** `with-claude-mount` does not work here — pods cannot bind-mount your laptop's `~/.claude`. Use `claude login` inside the pod instead.
- **Privileged containers are cluster-dependent.** `with-docker-in-docker` needs privileged mode. Whether your cluster allows that is a PodSecurity / admission-policy question. If denied, stick with the baseline.

## SSH / Neovim / bare terminal

You can attach any editor to an already-running container. The container gets its tooling from whichever launcher first started it — if you started it with `devpod up`, SSH'ing in later picks up the same Claude Code install.

To SSH into a running devpod workspace:

```bash
ssh <workspace-name>.devpod
```

devpod manages SSH configuration under `~/.ssh/config` automatically after `devpod up`.

## Verifying a fresh container

Inside the container, in Claude Code:

```
/verify-env
```

This probes `claude`, `gh`, `git`, `node` versions and prints a detection table showing which launcher you're in. See [slash commands](slash-commands.md) for details.
