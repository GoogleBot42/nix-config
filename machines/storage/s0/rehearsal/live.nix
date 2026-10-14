{ config, pkgs, lib, targetSystem, ... }:

# Added to the fleet's ephemeral ISO: bcachefs support, the rehearsal target's
# closure, and an unattended installer that runs when the virtio disks are seen.
{
  boot.supportedFilesystems = [ "bcachefs" ];
  system.extraDependencies = [ targetSystem ];
  environment.systemPackages = with pkgs; [ bcachefs-tools dosfstools efibootmgr ];

  systemd.services.s0-rehearsal-prep = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
    unitConfig.ConditionPathExists = "/dev/disk/by-id/virtio-nvmeA";
    path = with pkgs; [ util-linux cryptsetup bcachefs-tools dosfstools coreutils systemd config.system.build.nixos-install ];
    serviceConfig.Type = "oneshot";
    script = ''
      exec > /dev/ttyS0 2>&1
      set -x
      if ${pkgs.bash}/bin/bash ${./prep.sh} ${targetSystem}; then echo "=== PREP OK"; else echo "=== PREP FAILED rc=$?"; fi
      sync; systemctl poweroff
    '';
  };
}
