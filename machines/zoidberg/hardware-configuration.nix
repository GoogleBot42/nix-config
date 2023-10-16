{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # boot
  efi.enable = true;
  boot.loader.timeout = lib.mkForce 15;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];

  # kernel
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # disks
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/04231c41-2f13-49c0-8fce-0357eea67990";
    allowDiscards = true;

    # Fetch key from USB drive
    keyFileSize = 4096;
    keyFile = "/dev/disk/by-id/usb-Mass_Storage_Device_121220160204-0:0-part2";
    fallbackToPassword = true;
  };
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/39ee326c-a42f-49f3-84d9-f10091a903cd";
      fsType = "btrfs";
    };
  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/8074-B04D";
      fsType = "vfat";
    };
  swapDevices =
    [{ device = "/dev/disk/by-uuid/44e36954-9f1c-49ae-af07-72b240f93a95"; }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
