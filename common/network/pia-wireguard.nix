{ config, lib, pkgs, ... }:

# Server list:
#   https://serverlist.piaservers.net/vpninfo/servers/v6
# Reference materials:
#   https://github.com/pia-foss/manual-connections
#   https://github.com/thrnz/docker-wireguard-pia/blob/master/extra/wg-gen.sh

# TODO turn on firewall for VPN interface
# TODO handle potential errors (or at least print status, success, and failures to the console)
# TODO handle 2 month limit for port
# TODO handle VPN container with different name
# TODO parameterize names of systemd services so that multiple wg VPNs could coexist in theory easier
# TODO add some variance to the port forward timer
# TODO allow not forwarding a port
# TODO implement this module such that the wireguard VPN doesn't have to live in a container
# TODO look at wg-gen script for example of looking up a random server in a region and connect to that (user should not need to specify IP addr)

with builtins;

let
  cfg = config.pia.wireguard;

  getPIAToken = ''
    PIA_USER=`sed '1q;d' /run/agenix/pia-login.conf`
    PIA_PASS=`sed '2q;d' /run/agenix/pia-login.conf`
    # PIA_TOKEN only lasts 24hrs
    PIA_TOKEN=`curl -s -u "$PIA_USER:$PIA_PASS" https://www.privateinternetaccess.com/gtoken/generateToken | jq -r '.token'`
  '';
in {
  options.pia.wireguard = {
    enable = lib.mkEnableOption "Enable private internet access";
    serverHostname = lib.mkOption {
      type = lib.types.str;
      default = "zurich406";
    };
    serverIp = lib.mkOption {
      type = lib.types.str;
      default = "156.146.62.153";
    };
    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "piaw";
    };
    forwardedPort = lib.mkOption {
      type = lib.types.port;
      description = "The port to redirect port forwarded TCP VPN traffic too";
      default = 15050;
    };
    # TODO allow disabling this
    portForwarding = lib.mkEnableOption "Enables PIA port fowarding";

    # TODO implement this such that the wireguard VPN doesn't have to live in a container
    useInVPNContainer = lib.mkEnableOption "Configures the PIA WG VPN for use in the VPN container";
  };

  config = lib.mkIf cfg.enable {
    vpn-container.mounts = [ "/tmp/${cfg.interfaceName}.conf" "/tmp/${cfg.interfaceName}-address.conf" ];
    containers.vpn.interfaces = [ cfg.interfaceName ];

    # allow traffic for wireguard interface to pass since wireguard trips up rpfilter
    # networking.firewall = {
    #   extraCommands = ''
    #     ip46tables -t raw -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
    #     ip46tables -t raw -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
    #   '';
    #   extraStopCommands = ''
    #     ip46tables -t raw -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
    #     ip46tables -t raw -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
    #   '';
    # };
    networking.firewall.checkReversePath = "loose";

    systemd.services.pia-vpn-wireguard-init = {
      description = "Creates PIA VPN Wireguard Interface";

      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];
      before = [ "container@vpn.service" ];
      requiredBy = [ "container@vpn.service" ];
      partOf = [ "container@vpn.service" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ wireguard-tools jq curl iproute ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Prepare to connect by generating wg secrets and auth'ing with PIA since the container
        # cannot do without internet to start with. NAT'ing the host's internet would address this
        # issue but is not ideal because then leaking network outside of the VPN is more likely.

        WG_HOSTNAME=${cfg.serverHostname}
        WG_SERVER_IP=${cfg.serverIp}

        ${getPIAToken}

        privKey=$(wg genkey)
        pubKey=$(echo "$privKey" | wg pubkey)

        wireguard_json=`curl -s -G --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" --cacert "${./ca.rsa.4096.crt}" --data-urlencode "pt=$PIA_TOKEN" --data-urlencode "pubkey=$pubKey" https://$WG_HOSTNAME:1337/addKey`

        rm -f /tmp/${cfg.interfaceName}.conf /tmp/${cfg.interfaceName}-address.conf
        touch /tmp/${cfg.interfaceName}.conf /tmp/${cfg.interfaceName}-address.conf
        chmod 700 /tmp/${cfg.interfaceName}.conf /tmp/${cfg.interfaceName}-address.conf
        echo "               
        [Interface]
        # Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
        PrivateKey = $privKey
        ListenPort = 51820
        [Peer]
        PersistentKeepalive = 25
        PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
        AllowedIPs = 0.0.0.0/0
        Endpoint = $WG_SERVER_IP:$(echo "$wireguard_json" | jq -r '.server_port')
        " >> /tmp/${cfg.interfaceName}.conf
        echo "$wireguard_json" | jq -r '.peer_ip' >> /tmp/${cfg.interfaceName}-address.conf

        # Create wg interface now so it inherits from the namespace with internet access
        # the container will handle actually connecting the interface since that info is
        # not preserved upon moving into the container's networking namespace
        # Roughly following this guide https://www.wireguard.com/netns/#ordinary-containerization
        [[ -z $(ip link show dev ${cfg.interfaceName} 2>/dev/null) ]] || exit
        ip link add ${cfg.interfaceName} type wireguard
      '';

      preStop = ''
        ip link del ${cfg.interfaceName}
      '';
    };

    vpn-container.config.systemd.services.pia-vpn-wireguard = {
      description = "PIA VPN WireGuard Tunnel";

      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ wireguard-tools iproute curl jq iptables ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # pseudo calls wg-quick
        # wg-quick down /tmp/${cfg.interfaceName}.conf
        # cannot actually call wg-quick because the interface has to be already created at this point

        # assumes wg interface was already created
        # ip link add ${cfg.interfaceName} type wireguard

        myaddress=`cat /tmp/${cfg.interfaceName}-address.conf`

        wg setconf ${cfg.interfaceName} /tmp/${cfg.interfaceName}.conf
        ip -4 address add $myaddress dev ${cfg.interfaceName}
        ip link set mtu 1420 up dev ${cfg.interfaceName}
        wg set ${cfg.interfaceName} fwmark 51820
        ip -4 route add 0.0.0.0/0 dev ${cfg.interfaceName} table 51820

        # TODO is this needed?
        ip -4 rule add not fwmark 51820 table 51820
        ip -4 rule add table main suppress_prefixlength 0
        # sysctl -q net.ipv4.conf.all.src_valid_mark=1

        # Reserve port
        ${getPIAToken}
        payload_and_signature=`curl -s -m 5 --connect-to "${cfg.serverHostname}::${cfg.serverIp}:" --cacert "${./ca.rsa.4096.crt}" -G --data-urlencode "token=$PIA_TOKEN" "https://${cfg.serverHostname}:19999/getSignature"`
        signature=$(echo "$payload_and_signature" | jq -r '.signature')
        payload=$(echo "$payload_and_signature" | jq -r '.payload')
        port=$(echo "$payload" | base64 -d | jq -r '.port')

        # write reserved port to file readable for all users
        echo $port > /tmp/${cfg.interfaceName}-port
        chmod 644 /tmp/${cfg.interfaceName}-port

        # write payload and signature info needed to allow refreshing allocated forwarded port
        rm -f /tmp/${cfg.interfaceName}-port-renewal
        touch /tmp/${cfg.interfaceName}-port-renewal
        chmod 700 /tmp/${cfg.interfaceName}-port-renewal
        echo $signature >> /tmp/${cfg.interfaceName}-port-renewal
        echo $payload >> /tmp/${cfg.interfaceName}-port-renewal

        # redirect the fowarded port
        # iptables -A INPUT -i ${cfg.interfaceName} -p tcp --dport $port -j ACCEPT
        # iptables -A INPUT -i ${cfg.interfaceName} -p udp --dport $port -j ACCEPT
        # iptables -A INPUT -i ${cfg.interfaceName} -p tcp --dport ${toString cfg.forwardedPort} -j ACCEPT
        # iptables -A INPUT -i ${cfg.interfaceName} -p udp --dport ${toString cfg.forwardedPort} -j ACCEPT
        # iptables -A PREROUTING -t nat -i ${cfg.interfaceName} -p tcp --dport $port -j REDIRECT --to-port ${toString cfg.forwardedPort}
        # iptables -A PREROUTING -t nat -i ${cfg.interfaceName} -p udp --dport $port -j REDIRECT --to-port ${toString cfg.forwardedPort}
      '';

      preStop = ''
        wg-quick down /tmp/${cfg.interfaceName}.conf

        # stop redirecting the forwarded port
        # iptables -D INPUT -i ${cfg.interfaceName} -p tcp --dport $port -j ACCEPT
        # iptables -D INPUT -i ${cfg.interfaceName} -p udp --dport $port -j ACCEPT
        # iptables -D INPUT -i ${cfg.interfaceName} -p tcp --dport ${toString cfg.forwardedPort} -j ACCEPT
        # iptables -D INPUT -i ${cfg.interfaceName} -p udp --dport ${toString cfg.forwardedPort} -j ACCEPT
        # iptables -D PREROUTING -t nat -i ${cfg.interfaceName} -p tcp --dport $port -j REDIRECT --to-port ${toString cfg.forwardedPort}
        # iptables -D PREROUTING -t nat -i ${cfg.interfaceName} -p udp --dport $port -j REDIRECT --to-port ${toString cfg.forwardedPort}
      '';
    };

    vpn-container.config.systemd.services.pia-vpn-wireguard-forward-port = {
      enable = cfg.portForwarding;
      description = "PIA VPN WireGuard Tunnel Port Forwarding";
      after = [ "pia-vpn-wireguard.service" ];
      requires = [ "pia-vpn-wireguard.service" ];

      path = with pkgs; [ curl ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        signature=`sed '1q;d' /tmp/${cfg.interfaceName}-port-renewal`
        payload=`sed '2q;d' /tmp/${cfg.interfaceName}-port-renewal`
        bind_port_response=`curl -Gs -m 5 --connect-to "${cfg.serverHostname}::${cfg.serverIp}:" --cacert "${./ca.rsa.4096.crt}" --data-urlencode "payload=$payload" --data-urlencode "signature=$signature" "https://${cfg.serverHostname}:19999/bindPort"`
      '';
    };

    vpn-container.config.systemd.timers.pia-vpn-wireguard-forward-port = {
      enable = cfg.portForwarding;
      partOf = [ "pia-vpn-wireguard-forward-port.service" ];
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*:0/10"; # 10 minutes
    };

    age.secrets."pia-login.conf".file = ../../secrets/pia-login.conf;
  };
}