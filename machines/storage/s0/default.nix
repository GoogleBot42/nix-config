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

  pia-vpn = {
    enable = true;
    serverLocation = "swiss";

    containers.transmission = {
      ip = "10.100.0.10";
      mounts."/var/lib".hostPath = "/var/lib";
      mounts."/data/samba/Public".hostPath = "/data/samba/Public";
      receiveForwardedPort = { protocol = "both"; };
      onPortForwarded = ''
        # Notify Transmission of the PIA-assigned peer port via RPC
        for i in $(seq 1 30); do
          curlout=$(curl -s "http://transmission.containers:80/transmission/rpc" 2>/dev/null) && break
          sleep 2
        done
        regex='X-Transmission-Session-Id: (\w*)'
        if [[ $curlout =~ $regex ]]; then
          sessionId=''${BASH_REMATCH[1]}
          curl -s "http://transmission.containers:80/transmission/rpc" \
            -d "{\"method\":\"session-set\",\"arguments\":{\"peer-port\":$PORT}}" \
            -H "X-Transmission-Session-Id: $sessionId"
        fi
      '';
      config = {
        services.transmission = {
          enable = true;
          package = pkgs.transmission_4;
          performanceNetParameters = true;
          user = "public_data";
          group = "public_data";
          settings = {
            "download-dir" = "/data/samba/Public/Media/Transmission";
            "incomplete-dir" = "/var/lib/transmission/.incomplete";
            "incomplete-dir-enabled" = true;

            "rpc-enabled" = true;
            "rpc-port" = 80;
            "rpc-bind-address" = "0.0.0.0";
            "rpc-whitelist" = "127.0.0.1,10.100.*.*,192.168.*.*";
            "rpc-host-whitelist-enabled" = false;

            "port-forwarding-enabled" = true;
            "peer-port" = 51413;
            "peer-port-random-on-start" = false;

            "encryption" = 1;
            "lpd-enabled" = true;
            "dht-enabled" = true;
            "pex-enabled" = true;

            "blocklist-enabled" = true;
            "blocklist-updates-enabled" = true;
            "blocklist-url" = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

            "ratio-limit" = 3;
            "ratio-limit-enabled" = true;

            "download-queue-enabled" = true;
            "download-queue-size" = 20;
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
    };

    containers.servarr = {
      ip = "10.100.0.11";
      mounts."/var/lib".hostPath = "/var/lib";
      mounts."/data/samba/Public".hostPath = "/data/samba/Public";
      mounts."/run/agenix" = { hostPath = "/run/agenix"; isReadOnly = true; };
      config = {
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

        users.groups.public_data.gid = 994;
        users.users.public_data = {
          isSystemUser = true;
          group = "public_data";
          uid = 994;
        };
      };
    };
  };
  age.secrets.radarr-api-key.file = ../../../secrets/radarr-api-key.age;
  age.secrets.sonarr-api-key.file = ../../../secrets/sonarr-api-key.age;

  # jellyfin
  # jellyfin cannot run in the vpn container and use hardware encoding
  # I could not figure out how to allow the container to access the encoder
  services.jellyfin.enable = true;
  users.users.${config.services.jellyfin.user}.extraGroups = [ "public_data" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
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
        (mkVirtualHost "bazarr.s0.neet.dev" "http://servarr.containers:6767")
        (mkVirtualHost "radarr.s0.neet.dev" "http://servarr.containers:7878")
        (mkVirtualHost "lidarr.s0.neet.dev" "http://servarr.containers:8686")
        (mkVirtualHost "sonarr.s0.neet.dev" "http://servarr.containers:8989")
        (mkVirtualHost "prowlarr.s0.neet.dev" "http://servarr.containers:9696")
        (mkVirtualHost "transmission.s0.neet.dev" "http://transmission.containers:80")
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
        (mkVirtualHost "memos.s0.neet.dev" "http://localhost:${toString config.services.memos.settings.MEMOS_PORT}")
        (mkVirtualHost "outline.s0.neet.dev" "http://localhost:${toString config.services.outline.port}")
        (mkVirtualHost "languagetool.s0.neet.dev" "http://localhost:${toString config.services.languagetool.port}")
      ];

    tailscaleAuth = {
      enable = false; # Disabled for now because it doesn't work with tailscale's ACL tagged groups
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
        # "memos.s0.neet.dev" # messes up memos /auth route
        # "outline.s0.neet.dev" # messes up outline /auth route
        "languagetool.s0.neet.dev"
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
    environmentFile = "/run/agenix/linkwarden-environment";
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

  services.memos = {
    enable = true;
    settings.MEMOS_PORT = "57643";
  };

  services.outline = {
    enable = true;
    forceHttps = false; # https through nginx
    port = 43933;
    publicUrl = "https://outline.s0.neet.dev";
    storage.storageType = "local";
    smtp = {
      secure = true;
      fromEmail = "robot@runyan.org";
      username = "robot@runyan.org";
      replyEmail = "robot@runyan.org";
      host = "mail.neet.dev";
      port = 465;
      passwordFile = "/run/agenix/robots-email-pw";
    };
  };
  age.secrets.robots-email-pw = {
    file = ../../../secrets/robots-email-pw.age;
    owner = config.services.outline.user;
  };

  services.languagetool = {
    enable = true;
    port = 60613;
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" ];
}
