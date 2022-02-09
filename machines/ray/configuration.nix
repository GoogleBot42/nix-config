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
    device = "/dev/disk/by-uuid/d71ebe1f-7c49-454d-b28b-1dc54cf280e5";
    allowDiscards = true;
  };

  networking.hostName = "ray";

  hardware.enableAllFirmware = true;

  boot.blacklistedKernelModules = [ "btusb" ];

  # fix backlight
  boot.kernelParams = [ "amdgpu.backlight=0" ];

  # newer kernel for wifi
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_5_15;

  # gpu
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.logFile = "/var/log/Xorg.0.log";
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
