{ lib, symlinkJoin, writeShellApplication, jq, coreutils, gnugrep, tmux, libnotify
, backend ? "tmux", cmux ? null }:
assert lib.assertOneOf "backend" backend [ "tmux" "cmux" ];
assert backend == "cmux" -> cmux != null;
let
  mk = name: file: deps: extra: writeShellApplication ({
    inherit name;
    runtimeInputs = deps;
    text = builtins.readFile file;
  } // extra);
  mux = if backend == "cmux" then cmux else tmux;
in
symlinkJoin {
  name = "claude-restore";
  paths = [
    (mk "claude-sessions-save" ./save.sh [ jq coreutils gnugrep ] { })
    (mk "claude-restore" ./restore.sh [ jq coreutils mux libnotify ] {
      runtimeEnv.CLAUDE_RESTORE_BACKEND = backend;
    })
  ];
  meta = {
    description = "Reopen Claude Code sessions in tmux or cmux after a reboot";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "claude-restore";
  };
}
