{ config, pkgs, lib, mkVpnContainer, ... }:

{
  imports =[
    ./helios64
    ./hardware-configuration.nix
  ];

  # nsw2zwifzyl42mbhabayjo42b2kkq3wd3dqyl6efxsz6pvmgm5cup5ad.onion

  networking.hostName = "s0";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  system.autoUpgrade.enable = true;

  boot.supportedFilesystems = [ "bcachefs" ];

  services.zerotierone.enable = true;

  # for education purposes only
  services.pykms.enable = true;
  services.pykms.openFirewallPort = true;

  users.users.googlebot.packages = with pkgs; [
    bcachefs-tools
  ];

  services.samba.enable = true;

  services.plex = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/plex";
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/data/samba/Public/Plex/Music";
    };
  };

  users.users.${config.services.plex.user}.extraGroups = [ "public_data" ];
  users.users.${config.services.jellyfin.user}.extraGroups = [ "public_data" ];
  users.users.googlebot.extraGroups = [ "transmission" ];
  users.groups.transmission.gid = config.ids.gids.transmission;

  containers.vpn = mkVpnContainer pkgs "/data/samba/Public/Plex" {
    services.prowlarr.enable = true;
    services.sonarr.enable = true;
    services.bazarr.enable = true;
    services.radarr.enable = true;
    services.lidarr.enable = true;
    users.groups.transmission.members = [ "prowlarr" "sonarr" "bazarr" "radarr" "lidarr" ];
    services.transmission = {
      enable = true;
      performanceNetParameters = true;
      settings = {
        /* directory settings */
        # "watch-dir" = "/srv/storage/Transmission/To-Download";
        # "watch-dir-enabled" = true;
        "download-dir" = "/var/lib/transmission/Downloads";
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
        "ratio-limit" = 10;
        "ratio-limit-enabled" = true;

        "download-queue-enabled" = true;
        "download-queue-size" = 20; # gotta go fast
      };
    };
    users.groups.public_data.members = [ "prowlarr" "sonarr" "bazarr" "radarr" "lidarr" "transmission" ];
    users.groups.public_data.gid = 994;
  };
  # containers cannot unlock their own secrets right now. unlock it here
  age.secrets."pia-login.conf".file = ../../../secrets/pia-login.conf;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  # forwarding for vpn container
  networking.nat.enable = true;
  networking.nat.internalInterfaces = [
    "ve-vpn" # vpn container
  ];
  networking.nat.externalInterface = "eth0";

  # unpackerr
  # flaresolverr

  services.nginx.enable = true;
  services.nginx.virtualHosts."bazarr.s0".locations."/".proxyPass = "http://172.16.100.2:6767";
  services.nginx.virtualHosts."radarr.s0".locations."/".proxyPass = "http://172.16.100.2:7878";
  services.nginx.virtualHosts."lidarr.s0".locations."/".proxyPass = "http://172.16.100.2:8686";
  services.nginx.virtualHosts."sonarr.s0".locations."/".proxyPass = "http://172.16.100.2:8989";
  services.nginx.virtualHosts."prowlarr.s0".locations."/".proxyPass = "http://172.16.100.2:9696";
  services.nginx.virtualHosts."music.s0".locations."/".proxyPass = "http://localhost:4533";
  services.nginx.virtualHosts."plex.s0".locations."/" = {
    proxyPass = "http://localhost:32400";
    proxyWebsockets = true;
  };
  services.nginx.virtualHosts."jellyfin.s0".locations."/" = {
    proxyPass = "http://localhost:8096";
    proxyWebsockets = true;
  };
  services.nginx.virtualHosts."transmission.s0".locations."/" = {
    proxyPass = "http://172.16.100.2:9091";
    proxyWebsockets = true;
  };

  # navidrome over cloudflare
  services.cloudflared = {
    enable = true;
    config = {
      url = config.services.nginx.virtualHosts."music.s0".locations."/".proxyPass;
      tunnel = "5975c2f1-d1f4-496a-a704-6d89ccccae0d";
      credentials-file = "/run/agenix/cloudflared-navidrome.json";
    };
  };
  age.secrets."cloudflared-navidrome.json".file = ../../../secrets/cloudflared-navidrome.json.age;

  nixpkgs.overlays = [
    (final: prev: {
      radarr = prev.radarr.overrideAttrs (old: rec {
        installPhase = ''
          runHook preInstall
          mkdir -p $out/{bin,share/${old.pname}-${old.version}}
          cp -r * $out/share/${old.pname}-${old.version}/.
          makeWrapper "${final.dotnet-runtime}/bin/dotnet" $out/bin/Radarr \
            --add-flags "$out/share/${old.pname}-${old.version}/Radarr.dll" \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
              final.curl final.sqlite final.libmediainfo final.mono final.openssl final.icu final.zlib ]}
          runHook postInstall
        '';
      });

      prowlarr = prev.prowlarr.overrideAttrs (old: {
        installPhase = ''
          runHook preInstall
          mkdir -p $out/{bin,share/${old.pname}-${old.version}}
          cp -r * $out/share/${old.pname}-${old.version}/.
          makeWrapper "${final.dotnet-runtime}/bin/dotnet" $out/bin/Prowlarr \
            --add-flags "$out/share/${old.pname}-${old.version}/Prowlarr.dll" \
            --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
              final.curl final.sqlite final.libmediainfo final.mono final.openssl final.icu final.zlib ]}
          runHook postInstall
        '';
      });
    })
  ];
}
