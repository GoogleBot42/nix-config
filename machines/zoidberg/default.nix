{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # services.spotifyd.enable = true;

  # wireless xbox controller support
  hardware.xpadneo.enable = true;

  services.mount-samba.enable = true;

  de.enable = true;

  # kodi
  services.xserver.desktopManager.kodi.enable = true;
  services.xserver.desktopManager.kodi.package =
    (
      pkgs.kodi.passthru.withPackages (kodiPackages: with kodiPackages; [
        jellyfin
        joystick
      ])
    );

  users.users.cris = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$LMGwHVauFWAcAyWSSmcuS/$BQpDyjDHZZbvj54.ijvNb03tr7IgX9wcjYCuCxjSqf6";
    uid = 1001;
    packages = with pkgs; [
      maestral
      maestral-gui
    ] ++ config.users.users.googlebot.packages;
  };
}
