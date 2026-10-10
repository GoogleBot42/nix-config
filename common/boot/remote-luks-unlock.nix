{ config, pkgs, lib, utils, ... }:

# TODO: use tailscale instead of tor https://gist.github.com/antifuchs/e30d58a64988907f282c82231dde2cbc

let
  cfg = config.remoteLuksUnlock;
  askPasswordShell = pkgs.writeShellScript "initrd-ask-password-shell" ''
    exec /bin/systemd-tty-ask-password-agent --watch
  '';

  # ZFS pools that hold a filesystem needed to reach stage 2.
  zfsRootPools = lib.unique (map (fs: lib.head (lib.splitString "/" fs.device))
    (lib.filter (fs: fs.fsType == "zfs" && utils.fsNeededForBoot fs) (lib.attrValues config.fileSystems)));
in
{
  options.remoteLuksUnlock = {
    enable = lib.mkEnableOption "enable luks root remote decrypt over ssh/tor";
    enableTorUnlock = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Make machine accessable over tor for ssh boot unlock";
    };
    sshHostKeys = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.path);
      default = [
        "/secret/ssh_host_rsa_key"
        "/secret/ssh_host_ed25519_key"
      ];
    };
    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.unique (
        config.users.users.root.openssh.authorizedKeys.keys
        ++ config.users.users.googlebot.openssh.authorizedKeys.keys
      );
    };
    onionConfig = lib.mkOption {
      type = lib.types.path;
      default = /secret/onion;
    };
    kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "e1000" "e1000e" "virtio_pci" "r8169" ];
    };
  };

  # A remote unlock may need several passphrase attempts; systemd-cryptsetup's
  # default of three leaves the initrd stuck with no prompt left to answer.
  options.boot.initrd.luks.devices = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      config.crypttabExtraOpts = lib.mkIf cfg.enable [ "tries=0" ];
    });
  };

  config = lib.mkIf cfg.enable {
    # Unlock LUKS disk over ssh
    boot.initrd.network.enable = true;

    # The filesystems inside the LUKS volume only appear once someone has
    # entered the passphrase, which over ssh can take arbitrarily long. The
    # initrd's default DefaultDeviceTimeoutSec (90s) would fail their device
    # units first, pulling in emergency.target as soon as the unlock finishes.
    boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "infinity";
    boot.initrd.kernelModules = cfg.kernelModules;
    boot.initrd.network.ssh = {
      enable = true;
      port = 22;
      hostKeys = cfg.sshHostKeys;
      authorizedKeys = cfg.sshAuthorizedKeys;
    };

    # Use a wrapper shell so sshd gets a real executable path while still
    # launching systemd-tty-ask-password-agent for interactive LUKS unlock.
    boot.initrd.systemd.users.root.shell = askPasswordShell;

    # The root shell path referenced from /etc/passwd must itself be present in
    # the initrd store closure or sshd rejects the account before auth succeeds.
    boot.initrd.systemd.storePaths = [ askPasswordShell ] ++ lib.optionals cfg.enableTorUnlock [
      "${pkgs.tor}/bin/tor"
    ];

    # Tor hidden service for remote unlock over onion
    boot.initrd.secrets = lib.mkIf cfg.enableTorUnlock {
      "/etc/tor/onion/bootup" = cfg.onionConfig;
    };

    boot.initrd.systemd.services = lib.mkMerge [
      # A root pool's import unit is required by sysroot.mount and starts as
      # soon as modules are loaded; its script polls for the pool 60 times
      # and then exits 1, which fails sysroot.mount and drops the initrd to
      # emergency while the passphrase prompt is still up. Hold the import
      # until every crypttab device is open, however long that takes.
      (lib.genAttrs (map (pool: "zfs-import-${pool}") zfsRootPools) (_: {
        after = [ "cryptsetup.target" ];
        requires = [ "cryptsetup.target" ];
      }))
      {
        tor-unlock = lib.mkIf cfg.enableTorUnlock (
          let
            torRc = pkgs.writeText "tor.rc" ''
              DataDirectory /etc/tor
              SOCKSPort 127.0.0.1:9050 IsolateDestAddr
              SOCKSPort 127.0.0.1:9063
              HiddenServiceDir /etc/tor/onion/bootup
              HiddenServicePort 22 127.0.0.1:22
            '';
          in
          {
            description = "Tor Hidden Service for Boot Unlock";
            wantedBy = [ "initrd.target" ];
            after = [ "network.target" "sshd.service" ];
            wants = [ "network.target" ];

            # Stop cleanly before the root switch, otherwise tor is killed
            # mid-transition and the unit is carried into stage 2 as failed.
            before = [ "shutdown.target" "initrd-switch-root.target" ];
            conflicts = [ "shutdown.target" "initrd-switch-root.target" ];

            unitConfig.DefaultDependencies = false;

            preStart = ''
              # Fix permissions for tor
              chmod -R 700 /etc/tor

              ${pkgs.tor}/bin/tor -f ${torRc} --verify-config
            '';

            serviceConfig = {
              Type = "simple";
              ExecStart = "${pkgs.tor}/bin/tor -f ${torRc}";
            };
          }
        );
      }
    ];
  };
}
