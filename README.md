# claude-restore

Reopen your [Claude Code](https://claude.com/claude-code) sessions after a reboot.

- **Save**: a systemd user timer (every minute) reads `~/.claude/sessions/<pid>.json`,
  keeps the sessions whose process is alive and writes
  `~/.local/state/claude-restore/sessions.json`.
- **Restore**: at login, each session of the previous boot is reopened with
  `claude --resume <id>` in its original directory (`--dangerously-skip-permissions`
  is kept if it was set), either in a detached tmux session `cc-<name>` (attach with
  `prefix + s`) or in a [cmux](https://github.com/manaflow-ai/cmux) workspace named
  after the session.

The snapshot is tagged with the boot id, so the timer never overwrites a snapshot
that hasn't been restored yet. At most one interval of changes is lost.

Linux + systemd, with tmux or cmux.

## Usage

```nix
# flake.nix
inputs.claude-restore = {
  url = "github:tienedev/claude-restore";
  inputs.nixpkgs.follows = "nixpkgs";
};

# home-manager
imports = [ inputs.claude-restore.homeManagerModules.default ];
programs.claude-restore.enable = true;
```

| Option | Default | |
|---|---|---|
| `backend` | `"tmux"` | `"tmux"` or `"cmux"` |
| `cmuxPackage` | `null` | cmux package, required with `backend = "cmux"` |
| `interval` | `"1min"` | snapshot period |
| `restoreOnLogin` | `true` | restore automatically |
| `target` | `"graphical-session.target"` | use `"default.target"` on a headless box |

## Commands

```
claude-restore --list    # show the snapshot
claude-restore --force   # restore even if the snapshot is from the current boot
claude-sessions-save     # snapshot now
```
