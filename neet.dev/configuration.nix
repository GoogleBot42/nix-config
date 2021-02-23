{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./flakes.nix
      ./hardware-configuration.nix
#      ./nsd.nix
      ./thelounge.nix
      ./mumble.nix
      ./gitlab.nix
      ./video-stream.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "neetdev";
  networking.wireless.enable = false;

  # Set your time zone.
  time.timeZone = "America/New_York";

  networking.useDHCP = true; # just in case... (todo ensure false doesn't fuck up initrd)
  networking.interfaces.eno1.useDHCP = true;

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0VFnn3+Mh0nWeN92jov81qNE9fpzTAHYBphNoY7HUx"
    ];
  };

  environment.systemPackages = with pkgs; [
    wget kakoune
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
  security.acme.certs = {
    "pages.neet.dev" = {
      group = "nginx";
      domain = "*.pages.neet.dev";
      dnsProvider = "digitalocean";
      credentialsFile = "/var/lib/secrets/certs.secret";
    };
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 53 80 443 4444 ];
  networking.firewall.allowedUDPPorts = [ 53 80 443 4444 ];

  # LUKS
  boot.initrd.luks.devices.enc-pv.device = "/dev/disk/by-uuid/06f6b0bf-fe79-4b89-a549-b464c2b162a1";

  # Unlock LUKS disk over ssh
  boot.initrd.network.enable = true;
  boot.initrd.kernelModules = [ "e1000" "e1000e" "virtio_pci" ];
  boot.initrd.network.ssh = {
    enable = true;
    port = 22;
    hostKeys = [
      "/secret/ssh_host_rsa_key"
      "/secret/ssh_host_ed25519_key"
    ];
    authorizedKeys = config.users.users.googlebot.openssh.authorizedKeys.keys;
  };

  # TODO is this needed?
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

  system.stateVersion = "20.09";
}

