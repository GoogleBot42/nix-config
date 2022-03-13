{ config, pkgs, fetchurl, lib, ... }:

let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';
in
{
  disabledModules = [
    "hardware/video/nvidia.nix"
  ];
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
  ];

  nix.flakes.enable = true;

  firmware.x86_64.enable = true;
  efi.enable = true;

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/c1822e5f-4137-44e1-885f-954e926583ce";
    allowDiscards = true;
  };

  networking.hostName = "ray";

  hardware.enableAllFirmware = true;

  # newer kernel for wifi
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_5_15;

  # gpu
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.logFile = "/var/log/Xorg.0.log";
  hardware.nvidia.modesetting.enable = true; # for nvidia-vaapi-driver
  hardware.nvidia.prime = {
    # reverse_sync.enable = true;
    # offload.enable = true;
    sync.enable = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:4:0:0";
  };

  services.zerotierone.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}
