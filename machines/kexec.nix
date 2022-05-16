# From https://mdleom.com/blog/2021/03/09/nixos-oracle/#Build-a-kexec-tarball
# Builds a kexec img

{ config, pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/netboot/netboot.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # stripped down version of https://github.com/cleverca22/nix-tests/tree/master/kexec
  system.build = rec {
    image = pkgs.runCommand "image" { buildInputs = [ pkgs.nukeReferences ]; } ''
      mkdir $out
      if [ -f ${config.system.build.kernel}/bzImage ]; then
        cp ${config.system.build.kernel}/bzImage $out/kernel
      else
        cp ${config.system.build.kernel}/Image $out/kernel
      fi
      cp ${config.system.build.netbootRamdisk}/initrd $out/initrd
      nuke-refs $out/kernel
    '';
    kexec_script = pkgs.writeTextFile {
      executable = true;
      name = "kexec-nixos";
      text = ''
        #!${pkgs.stdenv.shell}
        set -e
        ${pkgs.kexectools}/bin/kexec -l ${image}/kernel --initrd=${image}/initrd --append="init=${builtins.unsafeDiscardStringContext config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
        sync
        echo "executing kernel, filesystems will be improperly umounted"
        ${pkgs.kexectools}/bin/kexec -e
      '';
    };
    kexec_tarball = pkgs.callPackage (modulesPath + "/../lib/make-system-tarball.nix") {
      storeContents = [
        {
          object = config.system.build.kexec_script;
          symlink = "/kexec_nixos";
        }
      ];
      contents = [ ];
    };
  };

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

  networking.hostName = "kexec";

  services.openssh = {
    enable = true;
    challengeResponseAuthentication = false;
    passwordAuthentication = false;
  };

  services.getty.autologinUser = "root";
  users.users.root.openssh.authorizedKeys.keys = (import ../common/ssh.nix).users;
}