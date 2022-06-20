{ config, pkgs, ... }:

let
  nix-locate = config.inputs.nix-locate.defaultPackage.${config.currentSystem};
in {
  imports = [
    ./flakes.nix
    ./auto-update.nix
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
    nix-locate
    jellyfin-media-player
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

  programs.command-not-found.enable = false;

  programs.fish = {
    enable = true;

    shellInit = let
      wrapper = pkgs.writeScript "command-not-found" ''
        #!${pkgs.bash}/bin/bash
        source ${nix-locate}/etc/profile.d/command-not-found.sh
        command_not_found_handle "$@"
      '';
    in ''
      # use nix-locate for command-not-found functionality
      function __fish_command_not_found_handler --on-event fish_command_not_found
          ${wrapper} $argv
      end

      # disable annoying fish shell greeting
      set fish_greeting
    '';
  };
}
