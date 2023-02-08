{ pkgs, ... }:

{
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "e1000" "e1000e" "virtio_pci" "r8169" ];
  boot.kernelParams = [
    "panic=30" "boot.panic_on_fail" # reboot the machine upon fatal boot issues
    "console=ttyS0" # enable serial console
    "console=tty1"
  ];
  boot.kernel.sysctl."vm.overcommit_memory" = "1";

  environment.systemPackages = with pkgs; [
    cryptsetup
    btrfs-progs
  ];
  environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    challengeResponseAuthentication = false;
    passwordAuthentication = false;
  };

  services.getty.autologinUser = "root";
  users.users.root.openssh.authorizedKeys.keys = (import ../common/ssh.nix).users;
}