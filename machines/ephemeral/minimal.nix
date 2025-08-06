{ config, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/channel.nix")
    ../../common/machine-info
    ../../common/ssh.nix
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "e1000"
    "e1000e"
    "virtio_pci"
    "r8169"
    "sdhci"
    "sdhci_pci"
    "mmc_core"
    "mmc_block"
  ];
  boot.kernelParams = [
    "console=ttyS0,115200" # enable serial console
  ];
  boot.kernel.sysctl."vm.overcommit_memory" = "1";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  system.stateVersion = "21.11";

  # hardware.enableAllFirmware = true;
  # nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    cryptsetup
    btrfs-progs
    git
    git-lfs
    wget
    htop
    dnsutils
    pciutils
    usbutils
    lm_sensors
  ];

  environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
    };
  };

  services.getty.autologinUser = "root";
  users.users.root.openssh.authorizedKeys.keys = config.machines.ssh.userKeys;
}
