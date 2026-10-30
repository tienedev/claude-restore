{ lib, stdenv, writeShellApplication, jq, coreutils, gnused, procps, util-linux, tmux, libnotify
, cmuxTui ? null, backend ? null }:
assert backend == null || lib.elem backend [ "tmux" "cmux" ];
writeShellApplication {
  name = "claude-restore";
  # macOS ships ps, column and its own notifications.
  runtimeInputs = [ jq coreutils gnused tmux ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ procps util-linux libnotify ]
    ++ lib.optional (cmuxTui != null) cmuxTui;
  runtimeEnv = lib.optionalAttrs (backend != null) { CLAUDE_RESTORE_BACKEND = backend; };
  text = builtins.readFile ./bin/claude-restore;
  meta = {
    description = "Reopen your Claude Code sessions in tmux or cmux after a reboot";
    homepage = "https://github.com/tienedev/claude-restore";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "claude-restore";
  };
}
