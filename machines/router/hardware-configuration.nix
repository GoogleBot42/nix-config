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
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # boot
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  # disks
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/6aa7f79e-bef8-4b0f-b22c-9d1b3e8ac94b";
      fsType = "ext4";
    };
  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/14dfc562-0333-4ddd-b10c-4eeefe1cd05f";
      fsType = "ext3";
    };
  swapDevices =
    [{ device = "/dev/disk/by-uuid/adf37c64-3b54-480c-a9a7-099d61c6eac7"; }];

  nixpkgs.hostPlatform = "x86_64-linux";
}
