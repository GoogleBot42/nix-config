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

  # ROCm
  hardware.opengl.extraPackages = with pkgs; [
    rocm-opencl-icd
    rocm-opencl-runtime
  ];
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  # System wide barrier instance
  systemd.services.barrier-sddm = {
    description = "Barrier mouse/keyboard share";
    requires = [ "display-manager.service" ];
    after = [ "network.target" "display-manager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
      # todo use user/group
    };
    path = with pkgs; [ barrier doas ];
    script = ''
      # Wait for file to show up. "display-manager.service" finishes a bit too soon
      while ! [ -e /run/sddm/* ]; do sleep 1; done;
      export XAUTHORITY=$(ls /run/sddm/*)
      # Disable crypto is fine because tailscale is E2E encrypting better than barrier could anyway
      barrierc -f --disable-crypto --name zoidberg ray.koi-bebop.ts.net
    '';
  };

  # Login into X11 plasma so barrier works well
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
    jellyfin-media-player
    config.services.xserver.desktopManager.kodi.package
    spotify
    retroarchFull
  ];

  # Command and Conquer Ports
  networking.firewall.allowedUDPPorts = [ 4321 27900 ];
  networking.firewall.allowedTCPPorts = [ 6667 28910 29900 29920 ];

  nixpkgs.config.rocmSupport = true;
  services.ollama = {
    enable = true;
    acceleration = "rocm";
  };
}
