# Recreate one detached tmux session per Claude Code session of the previous
# boot, running `claude --resume <id>`.
state="${XDG_STATE_HOME:-$HOME/.local/state}/claude-restore"
snap="$state/sessions.json"
boot=$(cat /proc/sys/kernel/random/boot_id)

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

# A tmux server started from a systemd service would die with the service's
# cgroup: start it in its own scope instead.
new_session() {
  if [[ -n ${XDG_RUNTIME_DIR:-} ]] && command -v systemd-run >/dev/null && ! tmux info >/dev/null 2>&1; then
    systemd-run --user --scope --quiet --collect -- tmux new-session -d "$@"
  else
    tmux new-session -d "$@"
  fi
}

n=0
while IFS=$'\t' read -r id cwd name skip; do
  [[ -d $cwd ]] || continue
  # tmux forbids '.' and ':' in session names.
  sess="cc-${name//[.:]/-}"
  tmux has-session -t "=$sess" 2>/dev/null && continue
  flags=""; [[ $skip == true ]] && flags=" --dangerously-skip-permissions"
  new_session -s "$sess" -c "$cwd"
  # Typed into the interactive shell: user env/aliases apply, and the shell
  # stays open once claude exits.
  tmux send-keys -t "=$sess:" "claude$flags --resume $id" Enter
  n=$((n + 1))
done < <(jq -r '.sessions[] | [.sessionId, .cwd, .name, (.skip | tostring)] | @tsv' "$snap")

mv "$snap" "$state/last-restored.json"
if ((n > 0)); then
  notify-send -a claude-restore "$n Claude session(s) restored" "tmux: prefix+s, sessions cc-*" 2>/dev/null || true
fi
echo "$n session(s) restored."
