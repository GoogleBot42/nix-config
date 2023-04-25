# Allows kexec'ing as an alternative to rebooting for machines that
# have luks encrypted partitions that need to be mounted at boot.
# These luks partitions will be automatically unlocked, no password,
# or any interaction needed whatsoever.

# This is accomplished by fetching the luks key(s) while the system is running,
# then building a temporary initrd that contains the luks key(s), and kexec'ing.

{ config, lib, pkgs, ... }:

{
  options.luks = {
    enableKexec = lib.mkEnableOption "Enable support for transparent passwordless kexec while using luks";
  };

  config = lib.mkIf config.luks.enableKexec {
    luks.fallbackToPassword = true;
    luks.disableKeyring = true;

    boot.initrd.luks.devices = lib.listToAttrs
      (builtins.map
        (item:
          {
            name = item;
            value = {
              masterKeyFile = "/etc/${item}.key";
            };
          })
        config.luks.deviceNames);

    systemd.services.prepare-luks-kexec-image = {
      description = "Prepare kexec automatic LUKS unlock on kexec reboot without a password";

      wantedBy = [ "kexec.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";

      path = with pkgs; [ file kexec-tools coreutils-full cpio findutils gzip xz zstd lvm2 xxd gawk ];

      # based on https://github.com/flowztul/keyexec
      script = ''
        system=/nix/var/nix/profiles/system
        old_initrd=$(readlink -f "$system/initrd")

        umask 0077
        CRYPTROOT_TMPDIR="$(mktemp -d --tmpdir=/dev/shm)"

        cleanup() {
          shred -fu "$CRYPTROOT_TMPDIR/initrd_contents/etc/"*.key || true
          shred -fu "$CRYPTROOT_TMPDIR/new_initrd" || true
          shred -fu "$CRYPTROOT_TMPDIR/secret/"* || true
          rm -rf "$CRYPTROOT_TMPDIR"
        }
        # trap cleanup INT TERM EXIT

        mkdir -p "$CRYPTROOT_TMPDIR"
        cd "$CRYPTROOT_TMPDIR"

        # Determine the compression type of the initrd image
        compression=$(file -b --mime-type "$old_initrd" | awk -F'/' '{print $2}')

        # Decompress the initrd image based on its compression type
        case "$compression" in
          gzip)
            gunzip -c "$old_initrd" > initrd.cpio
            ;;
          xz)
            unxz -c "$old_initrd" > initrd.cpio
            ;;
          zstd)
            zstd -d -c "$old_initrd" > initrd.cpio
            ;;
          *)
            echo "Unsupported compression type: $compression"
            exit 1
            ;;
        esac

        # Extract the contents of the cpio archive
        mkdir -p initrd_contents
        cd initrd_contents
        cpio -idv < ../initrd.cpio

        # Generate keys and add them to the extracted initrd filesystem
        luksDeviceNames=(${builtins.concatStringsSep " " config.luks.deviceNames})
        for item in "''${luksDeviceNames[@]}"; do
          dmsetup --showkeys table "$item" | cut -d ' ' -f5 | xxd -ps -g1 -r > "./etc/$item.key"
        done

        # Add normal initrd secrets too
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (dest: source:
            let source' = if source == null then dest else builtins.toString source; in
              ''
                mkdir -p $(dirname "./${dest}")
                cp -a ${source'} "./${dest}"
              ''
          ) config.boot.initrd.secrets)
        }

        # Create a new cpio archive with the modified contents
        find . | cpio -o -H newc -v > ../new_initrd.cpio

        # Compress the new cpio archive using the original compression type
        cd ..
        case "$compression" in
          gzip)
            gunzip -c new_initrd.cpio > new_initrd
            ;;
          xz)
            unxz -c new_initrd.cpio > new_initrd
            ;;
          zstd)
            zstd -c new_initrd.cpio > new_initrd
            ;;
        esac

        kexec --load "$system/kernel" --append "init=$system/init ${builtins.concatStringsSep " " config.boot.kernelParams}" --initrd "$CRYPTROOT_TMPDIR/new_initrd"
      '';
    };
  };
}
