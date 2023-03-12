{ config, pkgs, ... }:

{
  # kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "igb" "mt7915e" "xhci_pci" "ahci" "ehci_pci" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Enable serial output
  boot.kernelParams = [
    "panic=30" "boot.panic_on_fail" # reboot the machine upon fatal boot issues
    "console=ttyS0,115200n8" # enable serial console
  ];
  boot.loader.grub.extraConfig = "
    serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
    terminal_input serial
    terminal_output serial
  ";

  # firmware
  firmware.x86_64.enable = true;
  nixpkgs.config.allowUnfree = true;

  # boot
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  # disks
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv".device = "/dev/disk/by-uuid/9b090551-f78e-45ca-8570-196ed6a4af0c";
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/421c82b9-d67c-4811-8824-8bb57cb10fce";
      fsType = "btrfs";
    };
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/d97f324f-3a2e-4b84-ae2a-4b3d1209c689";
      fsType = "ext3";
    };
  swapDevices =
    [ { device = "/dev/disk/by-uuid/45bf58dd-67eb-45e4-9a98-246e23fa7abd"; }
    ];

  nixpkgs.hostPlatform = "x86_64-linux";
}
