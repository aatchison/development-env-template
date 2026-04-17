---
description: Verify the devcontainer environment is healthy (claude, gh, git, node, plus container detection).
---

# /verify-env

Run the same tool-presence probes the CI workflow runs, plus environment detection.

## Steps

1. Run each command below via the Bash tool. Capture the output (or the error) for each. Do not abort on a single failure — report all results together.

   ```bash
   claude --version
   gh --version
   git --version
   node --version
   ```

2. Detect the runtime environment by checking:
   - `/.dockerenv` exists → running inside a container.
   - `$REMOTE_CONTAINERS` set → VS Code Dev Containers.
   - `$CODESPACES` set → GitHub Codespaces.
   - `$DEVPOD` set → devpod.

   ```bash
   test -f /.dockerenv && echo "container: yes" || echo "container: no"
   echo "REMOTE_CONTAINERS=${REMOTE_CONTAINERS:-unset}"
   echo "CODESPACES=${CODESPACES:-unset}"
   echo "DEVPOD=${DEVPOD:-unset}"
   ```

3. Present a markdown table summarizing each check as `pass` or `fail` with the observed version / value. Example:

   | Check | Status | Detail |
   |-------|--------|--------|
   | claude | pass | 1.2.3 |
   | gh | pass | 2.40.0 |
   | container | pass | /.dockerenv present |

4. If anything fails, note which environment the user is in (per step 2) and suggest the most likely cause — usually "rebuild the container" or "re-run postCreateCommand".
