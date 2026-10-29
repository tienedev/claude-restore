{ config, lib, pkgs, ... }:
let
  cfg = config.programs.claude-restore;
in
{
  options.programs.claude-restore = {
    enable = lib.mkEnableOption "snapshot and restore of Claude Code sessions across reboots";

    package = lib.mkOption {
      type = lib.types.package;
      # Same tmux as the user's, so the client speaks the running server's protocol.
      default = pkgs.callPackage ./package.nix { tmux = config.programs.tmux.package; };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { tmux = config.programs.tmux.package; }";
      description = "The claude-restore package.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = "How often live sessions are snapshotted (systemd time span).";
    };

    restoreOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restore the previous boot's sessions when `target` starts.";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      description = "User target that triggers the restore (e.g. `default.target` on a headless machine).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.isLinux;
      message = "programs.claude-restore relies on /proc and systemd: Linux only.";
    }];

    home.packages = [ cfg.package ];

    systemd.user.services.claude-sessions-save = {
      Unit.Description = "Snapshot open Claude Code sessions";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe' cfg.package "claude-sessions-save";
      };
    };

    systemd.user.timers.claude-sessions-save = {
      Unit.Description = "Periodic snapshot of Claude Code sessions";
      Timer = {
        OnStartupSec = cfg.interval;
        OnUnitActiveSec = cfg.interval;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.claude-restore = lib.mkIf cfg.restoreOnLogin {
      Unit = {
        Description = "Restore Claude Code sessions from the previous boot";
        After = [ cfg.target ];
        PartOf = [ cfg.target ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe' cfg.package "claude-restore";
      };
      Install.WantedBy = [ cfg.target ];
    };
  };
}
