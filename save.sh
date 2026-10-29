# Snapshot the live Claude Code sessions from ~/.claude/sessions/<pid>.json.
# The snapshot carries the boot_id: while it comes from another boot it is
# waiting to be restored, so it is left untouched.
state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-restore"
snap="$state/sessions.json"
sessions_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
boot=$(cat /proc/sys/kernel/random/boot_id)
mkdir -p "$state"

if [[ -f $snap ]] && [[ $(jq -r .boot "$snap") != "$boot" ]]; then
  exit 0
fi

entries=()
shopt -s nullglob
for f in "$sessions_dir"/*.json; do
  pid=$(jq -r .pid "$f")
  [[ $(jq -r '.kind // "interactive"' "$f") == interactive ]] || continue
  kill -0 "$pid" 2>/dev/null || continue
  tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | grep -q claude || continue
  skip=false
  tr '\0' '\n' <"/proc/$pid/cmdline" | grep -qx -- --dangerously-skip-permissions && skip=true
  entries+=("$(jq -c --argjson skip "$skip" \
    '{sessionId, cwd, name: (.name // .sessionId[0:8]), skip: $skip}' "$f")")
done

tmp=$(mktemp "$state/.sessions.XXXXXX")
printf '%s\n' "${entries[@]}" | jq -s --arg boot "$boot" \
  '{boot: $boot, savedAt: (now | todate), sessions: map(select(. != null))}' >"$tmp"
mv "$tmp" "$snap"
