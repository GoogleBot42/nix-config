# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/4ba62b93-d30e-4638-b68f-c830e6edde48";
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/4ba62b93-d30e-4638-b68f-c830e6edde48";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/8C47-F740";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/2aee96fd-5132-480f-a798-c6b87be2ffd9"; }
    ];

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
