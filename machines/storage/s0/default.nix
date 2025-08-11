{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./frigate.nix
    ./home-automation.nix
  ];

  networking.hostName = "s0";

  # system.autoUpgrade.enable = true;

  nix.gc.automatic = lib.mkForce false; # allow the nix store to serve as a build cache

  # binary cache
  services.nix-serve = {
    enable = true;
    openFirewall = true;
    secretKeyFile = "/run/agenix/binary-cache-private-key";
  };
  age.secrets.binary-cache-private-key.file = ../../../secrets/binary-cache-private-key.age;
  # users.users.cache-push = {
  #   isNormalUser = true;
  #   openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpUZFFL9BpBVqeeU63sFPhR9ewuhEZerTCDIGW1NPSB" ];
  # };
  # nix.settings = {
  #   trusted-users = [ "cache-push" ];
  # };

  services.iperf3.enable = true;
  services.iperf3.openFirewall = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # for education purposes only
  services.pykms.enable = true;
  services.pykms.openFirewallPort = true;

  # samba
  services.samba.enable = true;

  # navidrome
  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/data/samba/Public/Media/Music";
    };
  };

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
    services.recyclarr = {
      enable = true;
      configuration = {
        radarr.radarr_main = {
          api_key = {
            _secret = "/run/credentials/recyclarr.service/radarr-api-key";
          };
          base_url = "http://localhost:7878";

          quality_definition.type = "movie";
        };
        sonarr.sonarr_main = {
          api_key = {
            _secret = "/run/credentials/recyclarr.service/sonarr-api-key";
          };
          base_url = "http://localhost:8989";

          quality_definition.type = "series";
        };
      };
    };

    systemd.services.recyclarr.serviceConfig.LoadCredential = [
      "radarr-api-key:/run/agenix/radarr-api-key"
      "sonarr-api-key:/run/agenix/sonarr-api-key"
    ];

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
        "ratio-limit" = 3;
        "ratio-limit-enabled" = true;

        "download-queue-enabled" = true;
        "download-queue-size" = 20; # gotta go fast
      };
    };
    # https://github.com/NixOS/nixpkgs/issues/258793
    systemd.services.transmission.serviceConfig = {
      RootDirectoryStartOnly = lib.mkForce (lib.mkForce false);
      RootDirectory = lib.mkForce (lib.mkForce "");
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
  age.secrets.radarr-api-key.file = ../../../secrets/radarr-api-key.age;
  age.secrets.sonarr-api-key.file = ../../../secrets/sonarr-api-key.age;

  # jellyfin
  # jellyfin cannot run in the vpn container and use hardware encoding
  # I could not figure out how to allow the container to access the encoder
  services.jellyfin.enable = true;
  users.users.${config.services.jellyfin.user}.extraGroups = [ "public_data" ];
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
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
  services.nginx = {
    enable = true;
    openFirewall = false; # All nginx services are internal
    virtualHosts =
      let
        mkHost = external: config:
          {
            ${external} = {
              useACMEHost = "s0.neet.dev"; # Use wildcard cert
              forceSSL = true;
              locations."/" = config;
            };
          };
        mkVirtualHost = external: internal:
          mkHost external {
            proxyPass = internal;
            proxyWebsockets = true;
          };
        mkStaticHost = external: static:
          mkHost external {
            root = static;
            tryFiles = "$uri /index.html ";
          };
      in
      lib.mkMerge [
        (mkVirtualHost "bazarr.s0.neet.dev" "http://vpn.containers:6767")
        (mkVirtualHost "radarr.s0.neet.dev" "http://vpn.containers:7878")
        (mkVirtualHost "lidarr.s0.neet.dev" "http://vpn.containers:8686")
        (mkVirtualHost "sonarr.s0.neet.dev" "http://vpn.containers:8989")
        (mkVirtualHost "prowlarr.s0.neet.dev" "http://vpn.containers:9696")
        (mkVirtualHost "transmission.s0.neet.dev" "http://vpn.containers:9091")
        (mkVirtualHost "unifi.s0.neet.dev" "https://localhost:8443")
        (mkVirtualHost "music.s0.neet.dev" "http://localhost:4533")
        (mkVirtualHost "jellyfin.s0.neet.dev" "http://localhost:8096")
        (mkStaticHost "s0.neet.dev" config.services.dashy.finalDrv)
        {
          # Landing page LAN redirect
          "s0" = {
            default = true;
            redirectCode = 302;
            globalRedirect = "s0.neet.dev";
          };
        }
        (mkVirtualHost "ha.s0.neet.dev" "http://localhost:${toString config.services.home-assistant.config.http.server_port}")
        (mkVirtualHost "esphome.s0.neet.dev" "http://localhost:6052")
        (mkVirtualHost "zigbee.s0.neet.dev" "http://localhost:55834")
        {
          "frigate.s0.neet.dev" = {
            # Just configure SSL, frigate module configures the rest of nginx
            useACMEHost = "s0.neet.dev";
            forceSSL = true;
          };
        }
        (mkVirtualHost "vacuum.s0.neet.dev" "http://192.168.1.125") # valetudo
        (mkVirtualHost "sandman.s0.neet.dev" "http://192.168.9.14:3000") # es
        (mkVirtualHost "todo.s0.neet.dev" "http://localhost:${toString config.services.vikunja.port}")
        (mkVirtualHost "budget.s0.neet.dev" "http://localhost:${toString config.services.actual.settings.port}") # actual budget
        (mkVirtualHost "linkwarden.s0.neet.dev" "http://localhost:${toString config.services.linkwarden.port}")
      ];

    tailscaleAuth = {
      enable = true;
      virtualHosts = [
        "bazarr.s0.neet.dev"
        "radarr.s0.neet.dev"
        "lidarr.s0.neet.dev"
        "sonarr.s0.neet.dev"
        "prowlarr.s0.neet.dev"
        "transmission.s0.neet.dev"
        "unifi.s0.neet.dev"
        # "music.s0.neet.dev" # messes up navidrome
        "jellyfin.s0.neet.dev"
        "s0.neet.dev"
        # "ha.s0.neet.dev" # messes up home assistant
        "esphome.s0.neet.dev"
        "zigbee.s0.neet.dev"
        "vacuum.s0.neet.dev"
        "todo.s0.neet.dev"
        "budget.s0.neet.dev"
        "linkwarden.s0.neet.dev"
      ];
      expectedTailnet = "koi-bebop.ts.net";
    };
  };

  # Get wildcard cert
  security.acme.certs."s0.neet.dev" = {
    dnsProvider = "digitalocean";
    credentialsFile = "/run/agenix/digitalocean-dns-credentials";
    extraDomainNames = [ "*.s0.neet.dev" ];
    group = "nginx";
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false; # sadly this erroneously fails
  };
  age.secrets.digitalocean-dns-credentials.file = ../../../secrets/digitalocean-dns-credentials.age;

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman.dockerSocket.enable = true; # TODO needed?
  services.dashy = {
    enable = true;
    settings = import ./dashy.nix;
  };

  services.unifi = {
    enable = true;
    openMinimalFirewall = true;
  };

  services.vikunja = {
    enable = true;
    port = 61473;
    frontendScheme = "https";
    frontendHostname = "todo.s0.neet.dev";
    settings = {
      service.enableregistration = false;
    };
  };
  backup.group."vikunja".paths = [
    "/var/lib/vikunja"
  ];

  services.actual.enable = true;

  services.linkwarden = {
    enable = true;
    enableRegistration = true;
    port = 41709;
    environment.NEXTAUTH_URL = "https://linkwarden.s0.neet.dev/api/v1/auth";
    environment.FLARESOLVERR_URL = "http://localhost:${toString config.services.flaresolverr.port}/v1";
    environmentFile = "/run/agenix/linkwarden-environment";
    package = pkgs.linkwarden.overrideAttrs (oldAttrs: {
      # Add patch that adds support for flaresolverr
      patches = oldAttrs.patches or [ ] ++ [
        # https://github.com/linkwarden/linkwarden/pull/1251
        ../../../patches/linkwarden-flaresolverr.patch
      ];
    });
  };
  age.secrets.linkwarden-environment.file = ../../../secrets/linkwarden-environment.age;
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;
  };

  services.flaresolverr = {
    enable = true;
    port = 48072;
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" ];
}
