{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  networking.hostName = "s0";

  system.autoUpgrade.enable = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # for education purposes only
  services.pykms.enable = true;
  services.pykms.openFirewallPort = true;

  # samba
  services.samba.enable = true;

  # disable suspend on lid close
  services.logind.lidSwitch = "ignore";

  # navidrome
  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/data/samba/Public/Media/Music";
    };
  };
  networking.firewall.allowedTCPPorts = [ config.services.navidrome.settings.Port ];

  # allow access to transmisson data
  users.users.googlebot.extraGroups = [ "transmission" ];
  users.groups.transmission.gid = config.ids.gids.transmission;

  vpn-container.enable = true;
  vpn-container.mounts = [
    "/var/lib"
    "/data/samba/Public"
  ];
  vpn-container.config = {
    # servarr services
    services.prowlarr.enable = true;
    services.sonarr.enable = true;
    services.sonarr.user = "public_data";
    services.sonarr.group = "public_data";
    services.bazarr.enable = true;
    services.bazarr.user = "public_data";
    services.bazarr.group = "public_data";
    services.radarr.enable = true;
    services.radarr.user = "public_data";
    services.radarr.group = "public_data";
    services.lidarr.enable = true;
    services.lidarr.user = "public_data";
    services.lidarr.group = "public_data";

    services.transmission = {
      enable = true;
      performanceNetParameters = true;
      user = "public_data";
      group = "public_data";
      settings = {
        /* directory settings */
        # "watch-dir" = "/srv/storage/Transmission/To-Download";
        # "watch-dir-enabled" = true;
        "download-dir" = "/data/samba/Public/Media/Transmission";
        "incomplete-dir" = "/var/lib/transmission/.incomplete";
        "incomplete-dir-enabled" = true;

        /* web interface, accessible from local network */
        "rpc-enabled" = true;
        "rpc-bind-address" = "0.0.0.0";
        "rpc-whitelist" = "127.0.0.1,192.168.*.*,172.16.*.*";
        "rpc-host-whitelist" = "void,192.168.*.*,172.16.*.*";
        "rpc-host-whitelist-enabled" = false;

        "port-forwarding-enabled" = true;
        "peer-port" = 50023;
        "peer-port-random-on-start" = false;

        "encryption" = 1;
        "lpd-enabled" = true; /* local peer discovery */
        "dht-enabled" = true; /* dht peer discovery in swarm */
        "pex-enabled" = true; /* peer exchange */

        /* ip blocklist */
        "blocklist-enabled" = true;
        "blocklist-updates-enabled" = true;
        "blocklist-url" = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

        /* download speed settings */
        # "speed-limit-down" = 1200;
        # "speed-limit-down-enabled" = false;
        # "speed-limit-up" = 500;
        # "speed-limit-up-enabled" = true;

        /* seeding limit */
        "ratio-limit" = 2;
        "ratio-limit-enabled" = true;

        "download-queue-enabled" = true;
        "download-queue-size" = 20; # gotta go fast
      };
    };
    users.groups.public_data.gid = 994;
    users.users.public_data = {
      isSystemUser = true;
      group = "public_data";
      uid = 994;
    };
  };
  pia.wireguard.badPortForwardPorts = [
    9696 # prowlarr
    8989 # sonarr
    6767 # bazarr
    7878 # radarr
    8686 # lidarr
    9091 # transmission web
  ];

  # jellyfin
  # jellyfin cannot run in the vpn container and use hardware encoding
  # I could not figure out how to allow the container to access the encoder
  services.jellyfin.enable = true;
  users.users.${config.services.jellyfin.user}.extraGroups = [ "public_data" ];
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  # nginx
  services.nginx.enable = true;
  services.nginx.virtualHosts."bazarr.s0".locations."/".proxyPass = "http://vpn.containers:6767";
  services.nginx.virtualHosts."radarr.s0".locations."/".proxyPass = "http://vpn.containers:7878";
  services.nginx.virtualHosts."lidarr.s0".locations."/".proxyPass = "http://vpn.containers:8686";
  services.nginx.virtualHosts."sonarr.s0".locations."/".proxyPass = "http://vpn.containers:8989";
  services.nginx.virtualHosts."prowlarr.s0".locations."/".proxyPass = "http://vpn.containers:9696";
  services.nginx.virtualHosts."music.s0".locations."/".proxyPass = "http://localhost:4533";
  services.nginx.virtualHosts."jellyfin.s0".locations."/" = {
    proxyPass = "http://localhost:8096";
    proxyWebsockets = true;
  };
  services.nginx.virtualHosts."jellyfin.neet.cloud".locations."/" = {
    proxyPass = "http://localhost:8096";
    proxyWebsockets = true;
  };
  services.nginx.virtualHosts."transmission.s0".locations."/" = {
    proxyPass = "http://vpn.containers:9091";
    proxyWebsockets = true;
  };
}
