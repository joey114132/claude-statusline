#!/usr/bin/env bash
# Copies statusline.sh to a fixed path and points statusLine in Claude Code's settings.json at it.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline.sh"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
target="$config_dir/claude-statusline/statusline.sh"
settings="$config_dir/settings.json"

command -v jq >/dev/null || { echo "jq is required: install it and run this again." >&2; exit 1; }

[ -f "$settings" ] || echo '{}' > "$settings"
jq -e 'type == "object"' "$settings" >/dev/null || { echo "$settings is not a JSON object; left untouched." >&2; exit 1; }

# The plugin cache path changes on every plugin update, so settings.json must
# point at a copy that stays put. Rerun this after updating the plugin.
mkdir -p "$(dirname "$target")"
cp "$src" "$target"
chmod +x "$target"
echo "script:   $target"

previous="$(jq -c '.statusLine // empty' "$settings")"
wanted="$(jq -cn --arg cmd "$target" '{type: "command", command: $cmd, padding: 0}')"
if [ "$previous" = "$wanted" ]; then
  echo "settings: statusLine already points here, nothing to change"
  exit 0
fi

backup="$settings.bak-$(date +%Y%m%d-%H%M%S)"
cp "$settings" "$backup"
tmp="$(mktemp)"
jq --argjson sl "$wanted" '.statusLine = $sl' "$settings" > "$tmp"
# cat instead of mv keeps the file's permissions and any symlink in place.
cat "$tmp" > "$settings"
rm -f "$tmp"

echo "settings: statusLine set in $settings"
echo "previous: ${previous:-none}"
echo "backup:   $backup"
