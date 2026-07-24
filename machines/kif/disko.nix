# Declarative disk layout for kif, applied at install time by nixos-anywhere.
#
# GPT on the single 300G disk (/dev/sda), BIOS boot:
#   sda1  1M    EF02  bios_grub (GRUB core.img embed area)
#   sda2  1G    ext4  /boot
#   sda3  16G   swap  (random-encrypted, fresh key every boot)
#   sda4  rest  LUKS2 "enc-pv" -> btrfs at / (compress=zstd)
#
# The LUKS passphrase for the INITIAL luksFormat is read from `passwordFile`
# below. nixos-anywhere ships a local key file to that path on the target
# before running disko:
#
#   nixos-anywhere --flake .#kif \
#     --disk-encryption-keys /tmp/disko-luks.key /path/to/local/luks-passphrase \
#     --extra-files /home/googlebot/workspace/kif-bootstrap/extra-files \
#     root@15.204.91.158
#
# That same passphrase is what you type into the remote-unlock ssh/tor session
# at every subsequent boot (disko does NOT persist the key file into settings,
# so boot is interactive, not key-file based).
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # GRUB embeds core.img here on BIOS/GPT. Created first (EF02).
            bios_grub = {
              size = "1M";
              type = "EF02";
            };

            boot = {
              size = "1G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };

            swap = {
              size = "16G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "enc-pv";
                settings.allowDiscards = true;
                passwordFile = "/tmp/disko-luks.key";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
