{ config, lib, pkgs, ... }:

# bcachefs's reconcile thread (the mover that puts copies on their target
# and turns replicas into stripes) sleeps until something wakes it. Work
# that is already in its persistent queue when it starts is not re-driven:
# on s0 16 GB of /data sat half-placed for ten days and four reboots until
# its sysfs wakeup triggers were written by hand (2026-10-31). Writing the
# triggers is a signal, nothing more: free when the queue is empty, and
# with work queued it only does what should have happened anyway. Remove
# once upstream drains a non-empty queue at mount.

let
  hasBcachefs = config.boot.supportedFilesystems.bcachefs or false;
  kick = pkgs.writeShellScript "bcachefs-reconcile-kick" ''
    for fs in /sys/fs/bcachefs/*/internal; do
      [ -d "$fs" ] || continue
      echo 1 > "$fs/trigger_reconcile_pending_wakeup"
      echo 1 > "$fs/trigger_reconcile_wakeup"
    done
  '';
in
{
  config = lib.mkIf hasBcachefs {
    systemd.services.bcachefs-reconcile-kick = {
      description = "Wake bcachefs reconcile for any queued work";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = kick;
      };
    };

    systemd.timers.bcachefs-reconcile-kick = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "1h";
        AccuracySec = "5m";
      };
    };
  };
}
