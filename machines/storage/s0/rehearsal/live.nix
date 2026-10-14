{ config, pkgs, lib, targetSystem, ... }:

# Added to the fleet's ephemeral ISO: bcachefs support, the rehearsal target's
# closure, and an unattended installer that runs when the virtio disks are seen.
{
  boot.supportedFilesystems = [ "bcachefs" ];
  # The rehearsal guest boots UEFI, as s0 does; the fleet image is BIOS-only.
  image.modules.iso = {
    isoImage.makeEfiBootable = true;
    isoImage.makeUsbBootable = true;
  };
  system.extraDependencies = [ targetSystem ];
  environment.systemPackages = with pkgs; [ bcachefs-tools dosfstools efibootmgr ];

  systemd.services.s0-rehearsal-prep = {
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
    unitConfig.ConditionPathExists = "/dev/disk/by-id/virtio-nvmeA";
    path = with pkgs; [ util-linux cryptsetup bcachefs-tools dosfstools coreutils systemd efibootmgr nixos-install-tools config.nix.package ];
    # journal+console reaches the serial console without owning the tty the
    # getty hangs up; writing /dev/ttyS0 directly made bcachefs format panic.
    serviceConfig = { Type = "oneshot"; StandardOutput = "journal+console"; StandardError = "inherit"; };
    script = ''
      set -x
      if ${pkgs.bash}/bin/bash ${./prep.sh} ${targetSystem}; then echo "=== PREP OK"; else echo "=== PREP FAILED rc=$?"; fi
      sync; systemctl poweroff
    '';
  };
}
