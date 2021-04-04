# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/vg-root";
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };

  fileSystems."/home" =
    { device = "/dev/mapper/vg-root";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/47b13d6a-0bbb-42a6-abd9-2b06f76d9718";
      fsType = "ext3";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/b7533a50-6dd2-4a64-953b-a8218e77d9fa"; }
    ];

}