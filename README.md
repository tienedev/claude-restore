# claude-restore

Reopen your [Claude Code](https://claude.com/claude-code) sessions after a reboot.

- **Record**: `SessionStart`/`SessionEnd` hooks record every interactive session:
  its id, directory, permission mode, and the tmux session or
  [cmux](https://github.com/manaflow-ai/cmux) workspace it runs in.
- **Restore**: after a reboot, each session of the previous boot is reopened with
  `claude --resume <id>` in its original directory and permission mode, back in
  tmux (`cc-<name>` sessions) or in its own cmux workspace.

Sessions you leave on purpose (`/exit`, `/clear`, `/resume`, logout) are
forgotten. Sessions killed by the shutdown are restored; one you closed by
killing its terminal well before shutting down is not.

Linux and macOS, bash ≥ 3.2, needs `jq` and tmux or cmux.

## Nix (home-manager)

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

The hooks are added to `programs.claude-code.settings` automatically. If you
manage Claude Code settings another way, merge
`config.programs.claude-restore.claudeHooks` into your `settings.hooks`.

| Option | Default | |
|---|---|---|
| `backend` | `null` | `"tmux"` or `"cmux"` for sessions started outside both (`null`: tmux if installed) |
| `cmuxPackage` | `null` | cmux package, to restore into cmux |
| `restoreOnLogin` | `true` | restore at login (systemd user service / launchd agent) |
| `target` | `"graphical-session.target"` | Linux: use `"default.target"` on a headless box |

## Commands

```
claude-restore list                 recorded sessions and their state
claude-restore restore [--force]    reopen the previous boot's sessions
                       [--dry-run]  show what would be reopened
claude-restore adopt                record sessions already running (after install)
```
