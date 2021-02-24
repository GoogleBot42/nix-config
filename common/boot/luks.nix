{ config, pkgs, lib, ... }:

{
  # Unlock LUKS disk over ssh
  boot.initrd.network.enable = true;
  boot.initrd.kernelModules = [ "e1000" "e1000e" "virtio_pci" "r8169" ];
  boot.initrd.network.ssh = {
    enable = true;
    port = 22;
    hostKeys = [
      "/secret/ssh_host_rsa_key"
      "/secret/ssh_host_ed25519_key"
    ];
    authorizedKeys = config.users.users.googlebot.openssh.authorizedKeys.keys;
  };

  boot.initrd.postDeviceCommands = ''
    echo 'waiting for root device to be opened...'
    mkfifo /crypt-ramfs/passphrase
    echo /crypt-ramfs/passphrase >> /dev/null
  '';

  # Make machine accessable over tor for boot unlock
  boot.initrd.secrets = {
    "/etc/tor/onion/bootup" = /secret/onion;
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
}
