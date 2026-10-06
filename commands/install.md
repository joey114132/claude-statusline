---
description: Install or update the claude-statusline status line (copies the script and sets statusLine in settings.json).
---

Run the installer and show the user its output verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh"
```

If it prints a `previous:` value other than `none`, tell the user their old statusLine setting was replaced and where the backup is. If it fails, show the error and stop; do not edit settings.json by hand.

Finish by telling the user the new status line appears after their next message, and that colors and thresholds are set in `~/.config/claude-statusline/config` (see `config.example` in the plugin).
