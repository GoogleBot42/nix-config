{ lib, config, pkgs, ... }:

let
  cfg = config.services.matrix;
  certs = config.security.acme.certs;
in {
  options.services.matrix = {
    enable = lib.mkEnableOption "enable matrix";
    element-web = {
      enable = lib.mkEnableOption "enable matrix web client";
      host = lib.mkOption {
        type = lib.types.str;
        description = "the https host to serve";
      };
    };
    jitsi-meet = {
      enable = lib.mkEnableOption "enable jisti meet + matrix integration";
      host = lib.mkOption {
        type = lib.types.str;
        description = "the https host to serve";
      };
    };
    turn = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "the https host to serve";
      };
      port = lib.mkOption {
        type = lib.types.int;
        default = 25999;
        description = "turn server port";
      };
      min-port = lib.mkOption {
        type = lib.types.int;
        default = 26000;
        description = "min turn server port";
      };
      max-port = lib.mkOption {
        type = lib.types.int;
        default = 26100;
        description = "max turn server port";
      };
      secret = lib.mkOption {
        type = lib.types.str;
        description = "the turn server secret";
      };
    };
    host = lib.mkOption {
      type = lib.types.str;
      description = "name of the matrix-synapse server";
    };
    enable_registration = lib.mkEnableOption "enable new user signup";
    port = lib.mkOption {
      type = lib.types.int;
      default = 45022;
      description = "internal matrix-synapse port";
    };
  };
  config = lib.mkIf cfg.enable {
    services.matrix-synapse = {
      enable = true;
      server_name = cfg.host;
      enable_registration = cfg.enable_registration;
      listeners = [ {
        bind_address = "127.0.0.1";
        port = cfg.port;
        tls = false;
        resources = [ {
          compress = true;
          names = [ "client" "federation" ];
        } ];
      } ];
      turn_uris = [
        "turn:${cfg.turn.host}:${toString cfg.turn.port}?transport=udp"
        "turn:${cfg.turn.host}:${toString cfg.turn.port}?transport=tcp"
      ];
      turn_shared_secret = cfg.turn.secret;
      turn_user_lifetime = "1h";
    };

    services.coturn = {
      enable = true;
      no-cli = true;
      min-port = cfg.turn.min-port;
      max-port = cfg.turn.max-port;
      use-auth-secret = true;
      static-auth-secret = cfg.turn.secret;
      realm = cfg.turn.host;
      cert = "${certs.${cfg.turn.host}.directory}/full.pem";
      pkey = "${certs.${cfg.turn.host}.directory}/key.pem";
      extraConfig = ''
        # ban private IP ranges
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.88.99.0-192.88.99.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=244.0.0.0-224.255.255.255
        denied-peer-ip=255.255.255.255-255.255.255.255
      '';
    };

    networking.firewall.allowedUDPPorts = [ cfg.turn.port ];
    networking.firewall.allowedTCPPorts = [ cfg.turn.port 8448 ];
    networking.firewall.allowedUDPPortRanges = [
      { from = cfg.turn.min-port; to = cfg.turn.max-port; }
    ];
    networking.firewall.allowedTCPPortRanges = [
      { from = cfg.turn.min-port; to = cfg.turn.max-port; }
    ];

    users.users.nginx.extraGroups = [ "turnserver" ];
    security.acme.certs.${cfg.turn.host} = {
      postRun = "systemctl restart coturn.service";
      group = "turnserver";
    };

    services.nginx = {
      enable = true;

      virtualHosts.${cfg.host} =  {
        enableACME = true;
        forceSSL = true;
        listen = [
          {
            addr = "0.0.0.0";
            port = 8448;
            ssl = true;
          }
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ];
        locations."/".proxyPass = "http://localhost:${toString cfg.port}";
      };
      virtualHosts.${cfg.turn.host} =  { # get TLS cert for TURN server
        enableACME = true;
        forceSSL = true;
      };

      virtualHosts.${cfg.element-web.host} = lib.mkIf cfg.element-web.enable {
        enableACME = true;
        forceSSL = true;
        locations."/".root = pkgs.element-web.override {
          conf = {
            default_server_config = {
              "m.homeserver" = {
                "base_url" = "https://${cfg.host}";
                "server_name" = cfg.host;
              };
              "m.identity_server" = {
                "base_url" = "https://vector.im";
              };
            };
            jitsi.preferredDomain = lib.mkIf cfg.jitsi-meet.enable cfg.jitsi-meet.host;
          };
        };
      };
    };

    services.postgresql.enable = true;
    services.postgresql.initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';

    services.jitsi-meet = lib.mkIf cfg.jitsi-meet.enable {
      enable = true;
      hostName = cfg.jitsi-meet.host;
      nginx.enable = true;
      config = {
        enableInsecureRoomNameWarning = true;
        fileRecordingsEnabled = false;
        liveStreamingEnabled = false;
        prejoinPageEnabled = true;
        preferH264 = true;
        disableH264 = false;
        desktopSharingFrameRate = {
          min = 5;
          max = 30;
        };
        # startScreenSharing = true;
        videoQuality = {
          disabledCodec = "VP8";
          preferredCodec = "H264";
          enforcePreferredCodec = true;
        };
        # p2p = {
        #   enabled = true;
        #   preferH264 = true;
        #   disabledCodec = "VP8";
        #   preferredCodec = "H264";
        #   disableH264 = false;
        # };
        requireDisplayName = false;
        disableThirdPartyRequests = true;
        localRecording.enabled = false;
        doNotStoreRoom = true;
      };
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };
    services.jitsi-videobridge = lib.mkIf cfg.jitsi-meet.enable {
      enable = true;
      openFirewall = true;
    };
  };
}