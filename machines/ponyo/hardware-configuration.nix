{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "nvme" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/enc-pv";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/d3a3777d-1e70-47fa-a274-804dc70ee7fd";
      fsType = "ext4";
    };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/b14668b8-9026-b041-8b71-f302b6b291bf";
      randomEncryption.enable = true;
    }
  ];

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = lib.mkDefault false;
  networking.interfaces.ens3.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}