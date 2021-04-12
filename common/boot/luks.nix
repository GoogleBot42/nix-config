{ config, pkgs, lib, ... }:

let
  cfg = config.luks;
in {
  options.luks = {
    enable = lib.mkEnableOption "enable luks root remote decrypt over ssh/tor";
    device = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "enc-pv";
      };
      path = lib.mkOption {
        type = lib.types.either lib.types.str lib.types.path;
      };
      allowDiscards = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
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
      default = config.users.users.googlebot.openssh.authorizedKeys.keys;
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

  config = lib.mkIf cfg.enable {
    boot.initrd.luks.devices.${cfg.device.name} = {
      device = cfg.device.path;
      allowDiscards = cfg.device.allowDiscards;
    };

    # Unlock LUKS disk over ssh
    boot.initrd.network.enable = true;
    boot.initrd.kernelModules = cfg.kernelModules;
    boot.initrd.network.ssh = {
      enable = true;
      port = 22;
      hostKeys = cfg.sshHostKeys;
      authorizedKeys = cfg.sshAuthorizedKeys;
    };

    boot.initrd.postDeviceCommands = ''
      echo 'waiting for root device to be opened...'
      mkfifo /crypt-ramfs/passphrase
      echo /crypt-ramfs/passphrase >> /dev/null
    '';

    # Make machine accessable over tor for boot unlock
    boot.initrd.secrets = {
      "/etc/tor/onion/bootup" = cfg.onionConfig;
    };
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.tor}/bin/tor
      copy_bin_and_libs ${pkgs.haveged}/bin/haveged
    '';
    # start tor during boot process
    boot.initrd.network.postCommands = let
      torRc = (pkgs.writeText "tor.rc" ''
        DataDirectory /etc/tor
        SOCKSPort 127.0.0.1:9050 IsolateDestAddr
        SOCKSPort 127.0.0.1:9063
        HiddenServiceDir /etc/tor/onion/bootup
        HiddenServicePort 22 127.0.0.1:22
      '');
    in ''
      # Add nice prompt for giving LUKS passphrase over ssh
      echo 'read -s -p "Unlock Passphrase: " passphrase && echo $passphrase > /crypt-ramfs/passphrase && exit' >> /root/.profile

      echo "tor: preparing onion folder"
      # have to do this otherwise tor does not want to start
      chmod -R 700 /etc/tor

      echo "make sure localhost is up"
      ip a a 127.0.0.1/8 dev lo
      ip link set lo up

      echo "haveged: starting haveged"
      haveged -F &

      echo "tor: starting tor"
      tor -f ${torRc} --verify-config
      tor -f ${torRc} &
    '';
  };
}
