{ lib, ... }:

let
  # Mono Gateway Development Kit (NXP LS1046A) port roles.
  # The vendor documentation describes 2x SFP+ and 3x RJ-45 ports, but does not
  # promise the final Linux interface-name ordering. Start with the common eth*
  # ordering and verify/correct these bindings from the serial console before
  # cutover.
  wan = "eth0"; # one SFP+ port, WAN DHCP
  lanTrunk = "eth1"; # the other SFP+ port, tagged VLAN trunk
  mainAccessIfs = [ "eth2" "eth3" "eth4" ]; # RJ-45 ports, untagged/native main LAN

  mainIf = "br-main";
  iotIf = "vlan-iot";
  managementIf = "vlan-management";

  mainCidr = "192.168.1.1/21";
  iotCidr = "192.168.8.1/22";
  managementCidr = "192.168.13.1/24";

  lanIfs = [ mainIf iotIf managementIf ];
  internetCidrs = [ mainCidr ];

  mkDhcpRange = { tag, start, end, netmask, leaseTime ? "12h" }:
    "set:${tag},${start},${end},${netmask},${leaseTime}";
  mkDhcpOption = tag: option: value:
    "tag:${tag},option:${option},${value}";
  mkDhcpStaticLease = { mac, hostname, address }:
    "${mac},${hostname},${address}";

  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  nftStringSet = values: "{ ${lib.concatMapStringsSep ", " (value: ''"${value}"'') values} }";
in
{
  # This machine adapts the current OpenWrt gateway backup from 2026-06-21 to
  # the Mono Gateway Development Kit instead of the earlier PC Engines APU2
  # target. The network policy is intentionally unchanged; only the hardware
  # shape and port roles move:
  #   SFP+ 1 -> ${wan}: WAN DHCP
  #   SFP+ 2 -> ${lanTrunk}: tagged VLAN trunk for main/iot/management
  #   RJ-45 ports -> ${lib.concatStringsSep ", " mainAccessIfs}: untagged/native main LAN
  # Confirm the eth* mapping from the UART console before production cutover.

  networking = {
    useDHCP = false;
    useNetworkd = true;
    dhcpcd.enable = false;
    nftables.enable = true;
    firewall.enable = lib.mkForce false;
    domain = "lan";
  };

  systemd.network = {
    enable = true;

    netdevs = {
      "10-${mainIf}".netdevConfig = {
        Kind = "bridge";
        Name = mainIf;
      };

      "20-vlan-main-trunk" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-main-trunk";
        };
        vlanConfig.Id = 5;
      };

      "20-${iotIf}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = iotIf;
        };
        vlanConfig.Id = 2;
      };

      "20-${managementIf}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = managementIf;
        };
        vlanConfig.Id = 4;
      };
    };

    networks = {
      "10-wan" = {
        matchConfig.Name = wan;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
        dhcpV4Config = {
          SendHostname = false;
          UseDNS = true;
          UseDomains = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      "20-main-access" = {
        matchConfig.Name = mainAccessIfs;
        networkConfig = {
          Bridge = mainIf;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "carrier";
      };

      "20-lan-trunk" = {
        matchConfig.Name = lanTrunk;
        networkConfig = {
          VLAN = [ "vlan-main-trunk" iotIf managementIf ];
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "carrier";
      };

      "30-vlan-main-trunk" = {
        matchConfig.Name = "vlan-main-trunk";
        networkConfig = {
          Bridge = mainIf;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "carrier";
      };

      "40-${mainIf}" = {
        matchConfig.Name = mainIf;
        address = [ mainCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${iotIf}" = {
        matchConfig.Name = iotIf;
        address = [ iotCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${managementIf}" = {
        matchConfig.Name = managementIf;
        address = [ managementCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = lanIfs;
      except-interface = wan;
      bind-dynamic = true;
      domain-needed = true;
      bogus-priv = true;
      localise-queries = true;
      rebind-protection = true;
      rebind-localhost-ok = true;
      local = "/lan/";
      domain = "lan";
      expand-hosts = true;
      cache-size = 1000;
      dhcp-authoritative = true;
      dhcp-lease-max = 300;
      edns-packet-max = 1232;

      dhcp-range = [
        # Pools cover the usable subnet; explicit pinned/static leases keep
        # devices such as s0 and fry at stable addresses.
        (mkDhcpRange { tag = "main"; start = "192.168.1.2"; end = "192.168.1.249"; netmask = "255.255.248.0"; })
        (mkDhcpRange { tag = "iot"; start = "192.168.8.2"; end = "192.168.8.249"; netmask = "255.255.252.0"; })
        (mkDhcpRange { tag = "management"; start = "192.168.13.2"; end = "192.168.13.249"; netmask = "255.255.255.0"; })
      ];

      dhcp-option = [
        (mkDhcpOption "main" "router" "192.168.1.1")
        (mkDhcpOption "main" "dns-server" "192.168.1.1")
        (mkDhcpOption "iot" "router" "192.168.8.1")
        (mkDhcpOption "iot" "dns-server" "192.168.8.1")
        (mkDhcpOption "management" "router" "192.168.13.1")
        (mkDhcpOption "management" "dns-server" "192.168.13.1")
      ];

      dhcp-host = [
        (mkDhcpStaticLease { mac = "58:11:22:D9:0F:74"; hostname = "s0"; address = "192.168.1.2"; })
        (mkDhcpStaticLease { mac = "58:11:22:D9:0F:75"; hostname = "s0"; address = "192.168.1.2"; })
        (mkDhcpStaticLease { mac = "70:C9:32:3D:20:02"; hostname = "vacuum"; address = "192.168.1.125"; })
        (mkDhcpStaticLease { mac = "9C:BF:0D:00:E3:56"; hostname = "fry"; address = "192.168.1.3"; })
        (mkDhcpStaticLease { mac = "C0:EE:40:A3:8C:32"; hostname = "eight-pod"; address = "192.168.9.14"; })
        (mkDhcpStaticLease { mac = "D4:43:0E:24:22:57"; hostname = "dog-cam"; address = "192.168.10.31"; })
      ];
    };
  };

  networking.nftables.tables.gateway = {
    family = "inet";
    content = ''
      set lan_ifaces {
        type ifname
        elements = ${nftStringSet lanIfs}
      }

      chain input {
        type filter hook input priority filter; policy drop;

        iifname "lo" accept
        ct state established,related accept
        ct state invalid drop

        # LAN VLANs may talk to the router for DHCP, SSH/admin, and local diagnostics.
        # Reject DNS queries from IoT and management to this router.
        iifname ${nftStringSet [ iotIf managementIf ]} udp dport 53 reject
        iifname ${nftStringSet [ iotIf managementIf ]} tcp dport 53 reject
        iifname @lan_ifaces accept

        # WAN input is not an exposed service surface. These rules only keep the
        # router's WAN client usable: DHCPv4 replies, DHCPv6 client traffic, and
        # the minimum ICMP/ICMPv6 needed for PMTU, errors, and IPv6 neighbor/router discovery.
        iifname "${wan}" udp sport 67 udp dport 68 accept
        iifname "${wan}" ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
        iifname "${wan}" udp dport 546 accept
        iifname "${wan}" ip6 saddr fe80::/10 icmpv6 type { mld-listener-query, mld-listener-report, mld-listener-done, mld2-listener-report } accept
        iifname "${wan}" icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } limit rate 1000/second accept
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        ct state established,related accept
        ct state invalid drop

        # Only the main VLAN is allowed to initiate Internet access. IoT and
        # management have no WAN forward rule, so they remain local-only unless a
        # future rule explicitly grants egress.
        iifname "${mainIf}" oifname "${wan}" accept

        # Forward inbound IPsec passthrough traffic to the main VLAN.
        iifname "${wan}" oifname "${mainIf}" ip protocol esp accept
        iifname "${wan}" oifname "${mainIf}" udp dport 500 accept

        # Permit forwarded IPv6 control/error traffic required for correct PMTU and NDP behavior.
        iifname "${wan}" ip6 nexthdr icmpv6 limit rate 1000/second accept
      }

      chain output {
        type filter hook output priority filter; policy accept;
      }
    '';
  };

  networking.nftables.tables.gateway-nat = {
    family = "ip";
    content = ''
      set internet4_subnets {
        type ipv4_addr
        flags interval
        elements = ${nftSet internetCidrs}
      }

      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        # Match the forward policy: NAT only subnets that are intentionally allowed to use WAN.
        oifname "${wan}" ip saddr @internet4_subnets masquerade
      }
    '';
  };

  assertions = [
    {
      assertion = !(builtins.elem wan ([ lanTrunk ] ++ mainAccessIfs))
        && !(builtins.elem lanTrunk mainAccessIfs)
        && builtins.length mainAccessIfs == builtins.length (lib.unique mainAccessIfs);
      message = "Gateway WAN, LAN trunk, and LAN access interfaces must be distinct.";
    }
  ];
}
