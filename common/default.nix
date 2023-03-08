{ config, pkgs, ... }:

let
  ssh = import ./ssh.nix;
  sshUserKeys = ssh.users;
  sshHigherTrustKeys = ssh.higherTrustUserKeys;
in
{
  imports = [
    ./flakes.nix
    ./auto-update.nix
    ./shell.nix
    ./network
    ./boot
    ./server
    ./pc
  ];

  nix.flakes.enable = true;

  system.stateVersion = "21.11";

  networking.useDHCP = false;

  networking.firewall.enable = true;
  networking.firewall.allowPing = true;

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };
  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    wget
    kakoune
    htop
    git git-lfs
    dnsutils
    tmux
    nethogs
    iotop
    pciutils
    usbutils
    killall
    screen
    micro
    helix
    lm_sensors
    picocom
  ];

  nixpkgs.config.allowUnfree = true;

  users.mutableUsers = false;
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "dialout" # serial
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = sshUserKeys;
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
    uid = 1000;
  };
  users.users.root = {
    openssh.authorizedKeys.keys = sshHigherTrustKeys;
  };
  nix.settings = {
    trusted-users = [ "root" "googlebot" ];
  };

  nix.gc.automatic = true;

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "zuckerberg@neet.dev";
}
