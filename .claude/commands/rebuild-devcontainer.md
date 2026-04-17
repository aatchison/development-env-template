---
description: Explain how to rebuild the devcontainer (Claude runs inside it and cannot rebuild itself).
---

# /rebuild-devcontainer

You are running **inside** the devcontainer you are being asked about. You cannot rebuild it. This command produces the right instructions for the user's launcher.

## Steps

1. Detect the launcher via env vars:

   ```bash
   echo "REMOTE_CONTAINERS=${REMOTE_CONTAINERS:-unset}"
   echo "CODESPACES=${CODESPACES:-unset}"
   echo "DEVPOD=${DEVPOD:-unset}"
   ```

2. Map the detection to instructions:

   - `$REMOTE_CONTAINERS` set → VS Code Dev Containers: "Open the Command Palette and run **Dev Containers: Rebuild Container**. To fully discard cached layers use **Dev Containers: Rebuild Container Without Cache**."
   - `$CODESPACES` set → GitHub Codespaces: "Open the Codespaces menu (bottom-left status bar) and select **Rebuild Container**. For a clean rebuild, use the GitHub web UI: … → `Full rebuild container`."
   - `$DEVPOD` set → devpod: "On your host (not inside the container), run `devpod up <workspace-name> --recreate`. Add `--reset` to discard the workspace volume."
   - None set → print all three with a note that the launcher could not be determined.

3. Remind the user: "Rebuilding exits this container session. Save any uncommitted work first."

4. Do NOT attempt any rebuild action yourself — this command is explanatory only.
