{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

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

  # wireless xbox controller support
  hardware.xone.enable = true;
  boot.kernelModules = [ "xone-wired" "xone-dongle" ];
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # ROCm
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
    rocmPackages.clr
  ];
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  services.displayManager.defaultSession = "plasma";

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
    inherit (config.users.users.googlebot) hashedPassword packages;
    uid = 1002;
  };

  # Auto login into Plasma in john zoidberg account
  services.displayManager.sddm.settings = {
    Autologin = {
      Session = "plasma";
      User = "john";
    };
  };

  environment.systemPackages = with pkgs; [
    config.services.xserver.desktopManager.kodi.package
    spotify
  ];

  # Command and Conquer Ports
  networking.firewall.allowedUDPPorts = [ 4321 27900 ];
  networking.firewall.allowedTCPPorts = [ 6667 28910 29900 29920 ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
  };
}
