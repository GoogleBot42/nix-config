{ config, pkgs, lib, ... }:

{
  disabledModules = [
    "hardware/video/nvidia.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
  ];

  firmware.x86_64.enable = true;
  efi.enable = true;

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/c1822e5f-4137-44e1-885f-954e926583ce";
    allowDiscards = true;
  };

  networking.hostName = "ray";

  hardware.enableAllFirmware = true;

  # newer kernel for wifi
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # gpu
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.logFile = "/var/log/Xorg.0.log";
  hardware.nvidia = {
    modesetting.enable = true; # for nvidia-vaapi-driver
    prime = {
      #reverse_sync.enable = true;
      offload.enable = true;
      offload.enableOffloadCmd = true;
      #sync.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:4:0:0";
    };
    powerManagement = {
#      enable = true;
#      finegrained = true;
      coarsegrained = true;
    };
  };


  virtualisation.docker.enable = true;

  services.zerotierone.enable = true;

  services.mount-samba.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}
