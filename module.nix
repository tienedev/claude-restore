{ config, lib, pkgs, options, ... }:
let
  cfg = config.programs.claude-restore;
  exe = lib.getExe cfg.package;
  hook = [{ hooks = [{ type = "command"; command = "${exe} hook"; }]; }];
in
{
  options.programs.claude-restore = {
    enable = lib.mkEnableOption "reopening Claude Code sessions after a reboot";

    backend = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "tmux" "cmux" ]);
      default = null;
      description = ''
        Where to reopen sessions that were not started in tmux or cmux.
        Sessions started in one of them always go back to it. `null`: tmux if
        installed, else cmux.
      '';
    };

    cmuxPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The cmux (cmux-tui) package, to reopen sessions in cmux.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      # Same tmux as the user's, so the client speaks the running server's protocol.
      default = pkgs.callPackage ./package.nix {
        inherit (cfg) backend;
        tmux = config.programs.tmux.package;
        cmuxTui = cfg.cmuxPackage;
      };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { ... }";
      description = "The claude-restore package.";
    };

    restoreOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Reopen the previous boot's sessions at login.";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = "Linux: user target that triggers the restore (`default.target` on a headless machine).";
    };

    claudeHooks = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = { SessionStart = hook; SessionEnd = hook; };
      description = ''
        The Claude Code hooks recording sessions. Added to
        `programs.claude-code.settings` when that module is used; otherwise
        merge them into your Claude Code `settings.hooks` yourself.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ cfg.package ];

      systemd.user.services.claude-restore = lib.mkIf (cfg.restoreOnLogin && pkgs.stdenv.hostPlatform.isLinux) {
        Unit = {
          Description = "Reopen Claude Code sessions from the previous boot";
          After = [ cfg.target ];
          PartOf = [ cfg.target ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${exe} restore";
        };
        Install.WantedBy = [ cfg.target ];
      };

      launchd.agents.claude-restore = lib.mkIf (cfg.restoreOnLogin && pkgs.stdenv.hostPlatform.isDarwin) {
        enable = true;
        config = {
          ProgramArguments = [ exe "restore" ];
          RunAtLoad = true;
        };
      };
    }
    (lib.optionalAttrs (options ? programs.claude-code.settings) {
      programs.claude-code.settings.hooks = cfg.claudeHooks;
    })
  ]);
}
