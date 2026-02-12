{ config, ... }:

# Adds additional kernel modules to the nixos system
# Not actually an overlay but a module. Has to be this way because kernel
# modules are tightly coupled to the kernel version they were built against.
# https://nixos.wiki/wiki/Linux_kernel

let
  cfg = config.kernel;
in
{ }
