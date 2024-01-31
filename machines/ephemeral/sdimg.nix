{ config, modulesPath, pkgs, lib, ... }:

let
  pinecube-uboot = pkgs.buildUBoot {
    defconfig = "pinecube_defconfig";
    extraMeta.platforms = [ "armv7l-linux" ];
    filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
  };
in
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image.nix")
    ./minimal.nix
  ];

  sdImage.populateFirmwareCommands = "";
  sdImage.populateRootCommands = ''
    mkdir -p ./files/boot
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
  '';
  sdImage.postBuildCommands = ''
    dd if=${pinecube-uboot}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
  '';

  ###

  networking.hostName = "pinecube";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.consoleLogLevel = 7;

  # cma is 64M by default which is waay too much and we can't even unpack initrd
  boot.kernelParams = [ "console=ttyS0,115200n8" "cma=32M" ];

  boot.kernelModules = [ "spi-nor" ]; # Not sure why this doesn't autoload. Provides SPI NOR at /dev/mtd0
  boot.extraModulePackages = [ config.boot.kernelPackages.rtl8189es ];

  zramSwap.enable = true; # 128MB is not much to work with

  sound.enable = true;

  environment.systemPackages = with pkgs; [
    ffmpeg
    (v4l_utils.override { withGUI = false; })
    usbutils
  ];

  services.getty.autologinUser = lib.mkForce "googlebot";
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
    openssh.authorizedKeys.keys = config.machines.ssh.userKeys;
  };

  networking.wireless.enable = true;
}
