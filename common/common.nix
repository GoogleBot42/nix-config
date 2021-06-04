{ config, pkgs, ... }:

{
  imports = [
    ./flakes.nix
    ./pia.nix
    ./zerotier.nix
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
    ./server/privatebin/privatebin.nix
    ./pc/de.nix
  ];

  system.stateVersion = "20.09";

  networking.useDHCP = false;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    wget kakoune htop git dnsutils tmux nethogs iotop
  ];

  nixpkgs.config.allowUnfree = true;

  users.mutableUsers = false;
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0VFnn3+Mh0nWeN92jov81qNE9fpzTAHYBphNoY7HUx" # reg
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSkKiRUUmnErOKGx81nyge/9KqjkPh8BfDk0D3oP586" # nat
    ];
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
  };
}
