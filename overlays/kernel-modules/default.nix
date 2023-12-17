{ config, lib, ... }:

# Adds additional kernel modules to the nixos system
# Not actually an overlay but a module. Has to be this way because kernel
# modules are tightly coupled to the kernel version they were built against.
# https://nixos.wiki/wiki/Linux_kernel

let
  cfg = config.kernel;

  gasket = config.boot.kernelPackages.callPackage ./gasket.nix { };
in
{
  options.kernel.enableGasketKernelModule = lib.mkEnableOption "Enable Gasket Kernel Module";

  config = lib.mkIf cfg.enableGasketKernelModule {
    boot.extraModulePackages = [ gasket ];
  };
}
