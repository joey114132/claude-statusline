#!/usr/bin/env bash
# Compact Claude Code statusline: gauge bars with the percentage inside, wraps by segment on narrow terminals.
set -u

input="$(cat)"

# Settings come from the environment or from the config file (file wins). Only
# STATUSLINE_*=<integer> lines are read, so the file is never executed.
config_file="${STATUSLINE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/claude-statusline/config}"
if [ -r "$config_file" ]; then
  while IFS='=' read -r key value; do
    value="${value%%#*}"
    value="${value//[[:space:]\"\']/}"
    [[ "$key" =~ ^STATUSLINE_[A-Z_]+$ && "$value" =~ ^[0-9]+$ ]] && printf -v "$key" '%s' "$value"
  done < "$config_file"
fi

int_setting() {
  local name="$1" default="$2" v="${!1:-}"
  [[ "$v" =~ ^[0-9]+$ ]] || v="$default"
  printf -v "$name" '%s' "$v"
}
int_setting STATUSLINE_WARN_PCT 50     # below this: warn color
int_setting STATUSLINE_CRIT_PCT 25     # below this: critical color
int_setting STATUSLINE_OK_COLOR 28     # 256-color codes for the filled cells
int_setting STATUSLINE_WARN_COLOR 166
int_setting STATUSLINE_CRIT_COLOR 124
int_setting STATUSLINE_EMPTY_COLOR 238
int_setting STATUSLINE_BAR_WIDTH 10
[ "$STATUSLINE_BAR_WIDTH" -lt 4 ] && STATUSLINE_BAR_WIDTH=4

if ! command -v jq >/dev/null 2>&1; then
  printf '[statusline] jq not found\n'
  exit 0
fi

ORANGE=$'\033[38;5;208m'
YELLOW=$'\033[33m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

model_id=''
current_dir=''
ctx_remaining=''
ctx_window_size=''
ctx_input_tokens=''
ctx_cache_creation_tokens=''
ctx_cache_read_tokens=''
five_used=''
five_reset=''
seven_used=''
seven_reset=''
total_cost=''
effort_level=''

parsed_vars="$(printf '%s' "$input" | jq -r '
  def s($v): ($v // "" | tostring | @sh);
  [
    "model_id=" + s(.model.id // .model.display_name // "unknown-model"),
    "current_dir=" + s(.workspace.current_dir // .cwd // "~"),
    "ctx_remaining=" + s(.context_window.remaining_percentage),
    "ctx_window_size=" + s(.context_window.context_window_size),
    "ctx_input_tokens=" + s(.context_window.current_usage.input_tokens),
    "ctx_cache_creation_tokens=" + s(.context_window.current_usage.cache_creation_input_tokens),
    "ctx_cache_read_tokens=" + s(.context_window.current_usage.cache_read_input_tokens),
    "five_used=" + s(.rate_limits.five_hour.used_percentage),
    "five_reset=" + s(.rate_limits.five_hour.resets_at),
    "seven_used=" + s(.rate_limits.seven_day.used_percentage),
    "seven_reset=" + s(.rate_limits.seven_day.resets_at),
    "total_cost=" + s(.cost.total_cost_usd),
    "effort_level=" + s(.effort.level)
  ] | .[]
' 2>/dev/null)" || {
  printf '[statusline] invalid input\n'
  exit 0
}
eval "$parsed_vars"
model_label="${model_id#claude-}"
display_dir="${current_dir%/}"
display_dir="${display_dir##*/}"
[ -z "$display_dir" ] && display_dir="$current_dir"

int_or_empty() {
  awk -v v="${1:-}" 'BEGIN { if (v ~ /^-?[0-9]+([.][0-9]+)?$/) printf "%d", v + 0.5 }'
}

# Draws the remaining percentage as a bar with the number centered inside it.
colored_pct() {
  local p text fill_bg filled start i ch out="" n="$STATUSLINE_BAR_WIDTH"
  local empty_bg=$'\033[48;5;'"$STATUSLINE_EMPTY_COLOR"'m' fg=$'\033[1;97m'
  p="$(int_or_empty "$1")"
  if [ -z "$p" ]; then
    p=0 text='--%'
  else
    [ "$p" -lt 0 ] && p=0
    [ "$p" -gt 100 ] && p=100
    text="${p}%"
  fi
  if [ "$p" -ge "$STATUSLINE_WARN_PCT" ]; then fill_bg="$STATUSLINE_OK_COLOR"
  elif [ "$p" -ge "$STATUSLINE_CRIT_PCT" ]; then fill_bg="$STATUSLINE_WARN_COLOR"
  else fill_bg="$STATUSLINE_CRIT_COLOR"; fi
  fill_bg=$'\033[48;5;'"$fill_bg"'m'
  filled=$(( (p * n + 50) / 100 ))
  start=$(( (n - ${#text}) / 2 ))
  for ((i = 0; i < n; i++)); do
    ch=' '
    [ "$i" -ge "$start" ] && [ "$i" -lt $((start + ${#text})) ] && ch="${text:$((i - start)):1}"
    if [ "$i" -lt "$filled" ]; then out="$out$fill_bg"; else out="$out$empty_bg"; fi
    out="$out$fg$ch"
  done
  printf '%s%s' "$out" "$RESET"
}

format_reset() {
  local epoch="${1:-}" fmt="$2"
  [ -z "$epoch" ] && return
  date -d "@$epoch" "+$fmt" 2>/dev/null || date -r "$epoch" "+$fmt" 2>/dev/null
}

format_k_tokens() {
  awk -v t="${1:-0}" 'BEGIN {
    if (t >= 1000000) printf "%.1fm", t / 1000000; else printf "%dk", int((t + 999) / 1000)
  }'
}

# Columns a string occupies on screen: emoji and ⏳ take 2, FE0F and ZWJ take 0.
display_width() {
  printf '%s' "$1" | perl -CS -ne '
    s/\e\[[0-9;]*m//g; my $w = 0;
    for my $o (map ord, split //) {
      next if $o == 0xFE0F || $o == 0x200D;
      $w += ($o >= 0x1F000 || ($o >= 0x2300 && $o <= 0x23FF) || ($o >= 0x1100 && $o <= 0x115F)
             || ($o >= 0x2E80 && $o <= 0xA4CF) || ($o >= 0xAC00 && $o <= 0xD7A3)) ? 2 : 1;
    }
    END { print $w }'
}

segs=("${BOLD}${ORANGE}[$model_label${effort_level:+ $effort_level}]${RESET}" "📁 $display_dir")

if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$current_dir" branch --show-current 2>/dev/null)"
  [ -z "$branch" ] && branch="$(git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)"
  segs+=("🌿 ${branch:-unknown}")
fi

ctx="💬 $(colored_pct "$ctx_remaining")"
window="$(int_or_empty "$ctx_window_size")"
if [ -n "$window" ] && [ "$window" -gt 0 ]; then
  used=$(( $(int_or_empty "${ctx_input_tokens:-0}") + $(int_or_empty "${ctx_cache_creation_tokens:-0}") + $(int_or_empty "${ctx_cache_read_tokens:-0}") ))
  left=$(( window - used ))
  [ "$left" -lt 0 ] && left=0
  ctx="$ctx $(format_k_tokens "$left")"
fi
segs+=("$ctx")

# Subscription: remaining quota (5h shows reset time, 7d reset date). API billing: cost so far.
left_of() { local u; u="$(int_or_empty "$1")"; [ -n "$u" ] && printf '%d' $((100 - u)); }
if [ -n "$five_used" ] || [ -n "$seven_used" ]; then
  five="⏳ 5h $(colored_pct "$(left_of "$five_used")")"
  t="$(format_reset "$five_reset" '%H:%M')"; [ -n "$t" ] && five="$five $t"
  seven="7d $(colored_pct "$(left_of "$seven_used")")"
  t="$(format_reset "$seven_reset" '%m-%d')"; [ -n "$t" ] && seven="$seven $t"
  segs+=("$five" "$seven")
elif awk -v c="$total_cost" 'BEGIN { exit !(c + 0 != 0) }'; then
  segs+=("💰 ${YELLOW}$(printf '$%.2f' "$total_cost")${RESET}")
fi

# Claude Code passes the terminal width in COLUMNS. Leave 2 columns for its indent and 2 for emoji width slop.
term_cols="$(int_or_empty "${COLUMNS:-}")"
max_width=$(( ${term_cols:-200} - 4 ))

line=""
for seg in "${segs[@]}"; do
  if [ -z "$line" ]; then
    line="$seg"
  elif [ "$(display_width "$line | $seg")" -gt "$max_width" ]; then
    printf '%s\n' "$line"
    line="$seg"
  else
    line="$line | $seg"
  fi
done
printf '%s\n' "$line"

exit 0
