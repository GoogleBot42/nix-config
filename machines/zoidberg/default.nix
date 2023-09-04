{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  de.enable = true;

  # Login DE Option: Steam
  programs.steam.gamescopeSession.enable = true;
  # programs.gamescope.capSysNice = true;

  # Login DE Option: Kodi
  services.xserver.desktopManager.kodi.enable = true;
  services.xserver.desktopManager.kodi.package =
    (
      pkgs.kodi.passthru.withPackages (kodiPackages: with kodiPackages; [
        jellyfin
        joystick
      ])
    );
  services.mount-samba.enable = true;

  # Login DE Option: RetroArch
  services.xserver.desktopManager.retroarch.enable = true;
  services.xserver.desktopManager.retroarch.package = pkgs.retroarchFull;

  # wireless xbox controller support
  hardware.xone.enable = true;
  boot.kernelModules = [ "xone-wired" "xone-dongle" ];
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  users.users.cris = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$LMGwHVauFWAcAyWSSmcuS/$BQpDyjDHZZbvj54.ijvNb03tr7IgX9wcjYCuCxjSqf6";
    uid = 1001;
    packages = with pkgs; [
      maestral
      maestral-gui
    ] ++ config.users.users.googlebot.packages;
  };

  # Dr. John A. Zoidberg
  users.users.john = {
    isNormalUser = true;
    hashedPassword = "";
    uid = 1002;
  };
}
