{ lib, symlinkJoin, writeShellApplication, jq, coreutils, gnugrep, tmux, libnotify }:
let
  mk = name: file: deps: writeShellApplication {
    inherit name;
    runtimeInputs = deps;
    text = builtins.readFile file;
  };
in
symlinkJoin {
  name = "claude-restore";
  paths = [
    (mk "claude-sessions-save" ./save.sh [ jq coreutils gnugrep ])
    (mk "claude-restore" ./restore.sh [ jq coreutils tmux libnotify ])
  ];
  meta = {
    description = "Reopen Claude Code sessions in tmux after a reboot";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "claude-restore";
  };
}
