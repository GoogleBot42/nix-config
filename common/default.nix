{ config, pkgs, lib, ... }:

{
  imports = [
    ./backups.nix
    ./binary-cache.nix
    ./flakes.nix
    ./auto-update.nix
    ./ntfy-alerts.nix
    ./zfs-alerts.nix
    ./shell.nix
    ./network
    ./boot
    ./server
    ./pc
    ./machine-info
    ./nix-builder.nix
    ./ssh.nix
    ./sandboxed-workspace
  ];

  nix.flakes.enable = true;

  system.stateVersion = "23.11";

  networking.useDHCP = lib.mkDefault true;

  networking.firewall.enable = true;
  networking.firewall.allowPing = true;

  time.timeZone = "America/Los_Angeles";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LANGUAGE = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };
  };

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
    git
    git-lfs
    dnsutils
    tmux
    nethogs
    iotop
    pciutils
    usbutils
    killall
    micro
    helix
    lm_sensors
    picocom
    lf
    gnumake
    tree
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
    openssh.authorizedKeys.keys = config.machines.ssh.userKeys;
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
    uid = 1000;
  };
  users.users.root = {
    openssh.authorizedKeys.keys = config.machines.ssh.deployKeys;
  };
  nix.settings = {
    trusted-users = [ "root" "googlebot" ];
  };

  # don't use sudo
  security.doas.enable = true;
  security.sudo.enable = false;
  security.doas.extraRules = [
    # don't ask for password every time
    { groups = [ "wheel" ]; persist = true; }
  ];

  nix.gc.automatic = true;

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "zuckerberg@neet.dev";

  # Enable Desktop Environment if this is a PC (machine role is "personal")
  de.enable = lib.mkDefault (config.thisMachine.hasRole."personal");
}
