{ config, pkgs, ... }:

{
  imports = [
    ./flakes.nix
    ./pia.nix
    ./zerotier.nix
    ./auto-update.nix
    ./boot/firmware.nix
    ./boot/efi.nix
    ./boot/bios.nix
    ./boot/luks.nix
    ./server/nginx.nix
    ./server/thelounge.nix
    ./server/mumble.nix
    ./server/icecast.nix
    ./server/nginx-stream.nix
    ./server/matrix.nix
    ./server/zerobin.nix
    ./server/gitea.nix
    ./server/privatebin/privatebin.nix
    ./server/drastikbot.nix
    ./server/radio.nix
    ./pc/de.nix
  ];

  system.stateVersion = "20.09";

  networking.useDHCP = false;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    wget kakoune htop git dnsutils tmux nethogs iotop pciutils
  ];

  nixpkgs.config.allowUnfree = true;

  users.mutableUsers = false;
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = (import ./ssh.nix).users;
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
  };
  nix.trustedUsers = [ "root" "googlebot" ];
}
