{ config, pkgs, ... }:

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

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;
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
    openssh.authorizedKeys.keys = (import ./ssh.nix).users;
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
    uid = 1000;
  };
  nix.trustedUsers = [ "root" "googlebot" ];

  nix.gc.automatic = true;

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "zuckerberg@neet.dev";
}
