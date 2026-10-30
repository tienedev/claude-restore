# Recreate one detached tmux session (or cmux workspace) per Claude Code
# session of the previous boot, running `claude --resume <id>`.
state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-restore"
snap="$state/sessions.json"
boot=$(cat /proc/sys/kernel/random/boot_id)
backend="${CLAUDE_RESTORE_BACKEND:-tmux}"

case "${1:-}" in
  -l|--list)
    f="$snap"; [[ -f $f ]] || f="$state/last-restored.json"
    [[ -f $f ]] || { echo "No snapshot."; exit 0; }
    jq -r '"snapshot \(.savedAt)", (.sessions[] | "  \(.name)\t\(.cwd)\t\(.sessionId)")' "$f"
    exit 0 ;;
  -f|--force) force=true ;;
  "") force=false ;;
  *) echo "Usage: claude-restore [--list|--force]" >&2; exit 1 ;;
esac

[[ -f $snap ]] || exit 0
if [[ $(jq -r .boot "$snap") == "$boot" ]] && ! $force; then
  echo "Snapshot is from the current boot: nothing to restore (--force to override)."
  exit 0
fi

# A server started from a systemd service would die with the service's
# cgroup: start it in its own scope instead.
in_scope() {
  if [[ -n ${XDG_RUNTIME_DIR:-} ]] && command -v systemd-run >/dev/null; then
    systemd-run --user --scope --quiet --collect -- "$@"
  else
    "$@"
  fi
}

# restore_<backend> <name> <cwd> <command>: returns 1 if already open.
restore_tmux() {
  # tmux forbids '.' and ':' in session names.
  local sess="cc-${1//[.:]/-}"
  tmux has-session -t "=$sess" 2>/dev/null && return 1
  if tmux info >/dev/null 2>&1; then
    tmux new-session -d -s "$sess" -c "$2"
  else
    in_scope tmux new-session -d -s "$sess" -c "$2"
  fi
  # Typed into the interactive shell: user env/aliases apply, and the shell
  # stays open once claude exits.
  tmux send-keys -t "=$sess:" "$3" Enter
}

restore_cmux() {
  local term
  cmux --json workspace list | jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null && return 1
  term=$(cmux --json workspace create --name "$1" | jq -r .value.terminal_id)
  # Same as tmux: typed into the workspace's interactive shell.
  cmux --quiet terminal "$term" write --text "cd $(printf %q "$2") && $3"$'\n'
}

case $backend in
  tmux) hint="tmux: prefix+s, sessions cc-*" ;;
  cmux)
    cmux server status >/dev/null 2>&1 || in_scope cmux --quiet server ensure
    hint="cmux: one workspace per session" ;;
  *) echo "Unknown backend: $backend" >&2; exit 1 ;;
esac

n=0
while IFS=$'\t' read -r id cwd name skip; do
  [[ -d $cwd ]] || continue
  flags=""; [[ $skip == true ]] && flags=" --dangerously-skip-permissions"
  "restore_$backend" "$name" "$cwd" "claude$flags --resume $id" || continue
  n=$((n + 1))
done < <(jq -r '.sessions[] | [.sessionId, .cwd, .name, (.skip | tostring)] | @tsv' "$snap")

mv "$snap" "$state/last-restored.json"
if ((n > 0)); then
  notify-send -a claude-restore "$n Claude session(s) restored" "$hint" 2>/dev/null || true
fi
echo "$n session(s) restored."
