{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    ./minimal.nix
  ];

  isoImage.makeUsbBootable = true;

  networking.hostName = "iso";
}