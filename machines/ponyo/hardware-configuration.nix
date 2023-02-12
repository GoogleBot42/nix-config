{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "nvme" ];
  boot.extraModulePackages = [ ];

  firmware.x86_64.enable = true;

  bios = {
    enable = true;
    device = "/dev/sda";
  };

  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv".device = "/dev/disk/by-uuid/4cc36be4-dbff-4afe-927d-69bf4637bae2";
  boot.initrd.luks.devices."enc-pv2".device = "/dev/disk/by-uuid/e52b01b3-81c8-4bb2-ae7e-a3d9c793cb00"; # expanded disk

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

  networking.interfaces.eth0.useDHCP = true;
}