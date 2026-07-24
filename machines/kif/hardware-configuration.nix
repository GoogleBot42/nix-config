{ config, lib, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # Intel Haswell KVM guest (lscpu: GenuineIntel)
  boot.extraModulePackages = [ ];

  firmware.x86_64.enable = true;

  # BIOS boot (no /sys/firmware/efi on this VPS). GRUB installs to /dev/sda;
  # the disko layout provides the 1M EF02 bios_grub partition it embeds into.
  bios = {
    enable = true;
    device = "/dev/sda";
    configurationLimit = 3; # Save room in /nix/store
  };

  # Both the `bios` module (via boot.loader.grub.device) and disko's EF02
  # bios_grub partition independently add "/dev/sda" to boot.loader.grub.devices,
  # which the GRUB module rejects as a duplicate in mirroredBoots. Collapse it
  # back to a single entry; grub still installs to /dev/sda.
  boot.loader.grub.devices = lib.mkForce [ "/dev/sda" ];

  # Remote LUKS unlock over ssh/tor in the initrd. The LUKS device itself
  # (enc-pv) and all filesystems/swap are declared by machines/kif/disko.nix,
  # so there are deliberately no boot.initrd.luks.devices / fileSystems /
  # swapDevices entries here.
  remoteLuksUnlock.enable = true;

  networking.usePredictableInterfaceNames = true;

  networking.useDHCP = false;
  networking.useNetworkd = true;

  # Give the initrd (remote-unlock) stage the same network as stage 2 so the
  # box is reachable for LUKS unlock before the root fs exists.
  boot.initrd.systemd.network.networks = config.systemd.network.networks;

  systemd.network.enable = true;
  systemd.network.networks."10-ens3" = {
    matchConfig.Name = "ens3";
    # IPv4 comes from DHCP (OVH). IPv6 is statically assigned by OVH/cloud-init:
    # a single /128 with an off-link default gateway reachable only via an
    # on-link route (netplan used `via ::` for the /64 + `via <gw>` for ::/0),
    # which systemd-networkd expresses as GatewayOnLink=yes.
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2604:2dc0:202:300::2436/128" ];
    routes = [
      { Gateway = "2604:2dc0:202:300::1"; GatewayOnLink = true; }
    ];
    linkConfig.RequiredForOnline = "routable";
  };
}
