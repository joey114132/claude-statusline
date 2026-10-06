# claude-statusline

A compact status line for Claude Code. It shows the model and effort level, the working folder and git branch, and three gauges: context remaining, 5-hour quota and 7-day quota. Each gauge prints its percentage inside the bar and changes color as the number drops.

```
[opus-5-5 high] | 📁 my-project | 🌿 main | 💬 [███79%██░░] 793k | ⏳ 5h [███80%██░░] 14:20 | 7d [███90%███░] 10-10
```

The real bars are colored cells with the number drawn on top, not block characters. A bar stays green while at least 50% remains, turns orange below 50% and red below 25%. Both thresholds and all colors can be changed.

The line fits the terminal width. Claude Code passes the current width to the script in `COLUMNS`, and when the full line does not fit, the script moves whole segments onto the next line instead of letting Claude Code cut them off with `…`. A 70-column pane gets two lines; a wide one gets one.

On API billing, where there is no quota, the two quota gauges are replaced by the session cost.

## Requirements

You need `bash`, `jq`, `perl` and `git`. It has been tested on Ubuntu with bash 5. macOS should work because the script falls back to BSD `date -r`, but that has not been tested.

## Install as a plugin

Run these inside Claude Code:

```
/plugin marketplace add joey114132/claude-statusline
/plugin install claude-statusline@claude-statusline
/claude-statusline:install
```

Plugins cannot set `statusLine` themselves, which is why the third command exists. It copies the script to `~/.claude/claude-statusline/statusline.sh` and sets `statusLine` in `~/.claude/settings.json` to point at that copy. Other settings stay as they are, and the old file is saved next to it as `settings.json.bak-<time>`. If a different status line was configured, the command shows what it replaced.

The copy is there because the plugin's own folder moves on every update. After updating the plugin, run `/claude-statusline:install` again to pick up the new script.

The repository is private, so Claude Code needs git access to it: an SSH key for an account that can see the repo, or HTTPS credentials set up with `gh auth login` and `gh auth setup-git`.

## Install from a clone

If you would rather track the repository directly, clone it and link the script into `~/.claude`. A later `git pull` then updates it in place:

```bash
git clone git@github.com:joey114132/claude-statusline.git ~/claude-statusline
ln -sf ~/claude-statusline/statusline.sh ~/.claude/statusline.sh
```

Then point Claude Code at it in `~/.claude/settings.json`. If a `statusLine` entry already exists, replace it:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

The new line appears after the next message.

## Configure

Put the settings you want to change in `~/.config/claude-statusline/config`, one per line. Anything left out keeps its default. For example, to turn bars orange below 60% and red below 30%:

```bash
mkdir -p ~/.config/claude-statusline
printf 'STATUSLINE_WARN_PCT=60\nSTATUSLINE_CRIT_PCT=30\n' > ~/.config/claude-statusline/config
```

`config.example` in this repository lists every setting with its default.

| Setting | Default | Meaning |
|---|---|---|
| `STATUSLINE_WARN_PCT` | 50 | below this, bars use the warn color |
| `STATUSLINE_CRIT_PCT` | 25 | below this, bars use the critical color |
| `STATUSLINE_OK_COLOR` | 28 (green) | 256-color code for the filled part |
| `STATUSLINE_WARN_COLOR` | 166 (orange) | |
| `STATUSLINE_CRIT_COLOR` | 124 (red) | |
| `STATUSLINE_EMPTY_COLOR` | 238 (grey) | color of the unfilled part |
| `STATUSLINE_BAR_WIDTH` | 10 | bar width in cells, at least 4 |

The script reads only `STATUSLINE_<NAME>=<integer>` lines from the file and never executes it, so a stray command in the config does nothing. Values that are not whole numbers fall back to the defaults. The same names also work as environment variables, but the file wins when both are set. To keep the config somewhere else, set `STATUSLINE_CONFIG` to its path.

To preview the 256 colors before choosing:

```bash
for c in $(seq 0 255); do printf '\033[48;5;%sm %3s \033[0m' "$c" "$c"; [ $((c % 16)) -eq 15 ] && echo; done
```

## Limits

Below about 40 columns, a single segment can be wider than the terminal, and Claude Code truncates that segment. The width calculation counts emoji as two columns, and the script leaves a 4-column margin because terminals do not all agree on emoji width. Whether Claude Code redraws the status line the moment the window is resized has not been checked; it does redraw on the next message.
