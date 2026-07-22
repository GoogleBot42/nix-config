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

  # Upstream resolvers for dnsmasq. systemd-resolved is disabled on this
  # machine and networkd's DHCP-learned DNS servers are not written anywhere
  # without it, so dnsmasq must be given explicit upstreams.
  upstreamDns = [ "1.1.1.1" "8.8.8.8" ];

  lanIfs = [ mainIf iotIf managementIf ];
  internetCidrs = [ mainCidr ];

  mkDhcpRange = { tag, start, end, netmask, leaseTime ? "12h" }:
    "set:${tag},${start},${end},${netmask},${leaseTime}";
  mkDhcpOption = tag: option: value:
    "tag:${tag},option:${option},${value}";
  # Omitting the value tells dnsmasq to not send the option at all instead of
  # defaulting to the router's own address.
  mkDhcpSuppressedOption = tag: option:
    "tag:${tag},option:${option}";
  # All MACs in one entry: dnsmasq refuses to start when the same address
  # appears in multiple dhcp-host lines.
  mkDhcpStaticLease = { macs, hostname, address }:
    "${lib.concatStringsSep "," macs},${hostname},${address}";

  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  nftStringSet = values: "{ ${lib.concatMapStringsSep ", " (value: ''"${value}"'') values} }";
in
{
  # This machine adapts the current OpenWrt gateway backup (APU2, backup from
  # 2026-07-21) to the Mono Gateway Development Kit. The network policy is
  # intentionally unchanged; only the hardware shape and port roles move:
  #   SFP+ 1 -> eth0 (wan): WAN DHCP
  #   SFP+ 2 -> eth1 (lanTrunk): tagged VLAN trunk for main/iot/management
  #   RJ-45 ports -> eth2/eth3/eth4 (mainAccessIfs): untagged/native main LAN
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
        # Solicit DHCPv6 (with prefix delegation) even if the ISP's router
        # advertisement does not set the M/O flags, matching OpenWrt's
        # unconditional wan6 dhcpv6 client.
        dhcpV6Config.WithoutRA = "solicit";
        linkConfig.RequiredForOnline = "routable";
      };

      # Bridge/trunk member ports must not gate systemd-networkd-wait-online:
      # an unplugged RJ-45 port would otherwise delay boot until the wait-online
      # timeout expires.
      "20-main-access" = {
        matchConfig.Name = mainAccessIfs;
        networkConfig = {
          Bridge = mainIf;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "20-lan-trunk" = {
        matchConfig.Name = lanTrunk;
        networkConfig = {
          VLAN = [ "vlan-main-trunk" iotIf managementIf ];
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "30-vlan-main-trunk" = {
        matchConfig.Name = "vlan-main-trunk";
        networkConfig = {
          Bridge = mainIf;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${mainIf}" = {
        matchConfig.Name = mainIf;
        address = [ mainCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          # IPv6 for the main LAN: take a prefix from the WAN DHCPv6 prefix
          # delegation and announce it via router advertisements. Clients get
          # SLAAC addresses and are pointed at this router's link-local address
          # (dnsmasq) for DNS. Requires IPv6 link-local on this interface.
          DHCPPrefixDelegation = true;
          IPv6SendRA = true;
        };
        ipv6SendRAConfig = {
          EmitDNS = true;
          DNS = "_link_local";
          EmitDomains = true;
          Domains = [ "lan" ];
        };
        linkConfig.RequiredForOnline = "no";
      };

      # IoT and management stay IPv4-only: they have no WAN egress, so global
      # IPv6 addresses would only widen their local attack surface.
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
      stop-dns-rebind = true;
      rebind-localhost-ok = true;
      # Only answer DNS for directly attached subnets (OpenWrt localservice).
      local-service = true;
      local = "/lan/";
      domain = "lan";
      expand-hosts = true;
      cache-size = 1000;
      dhcp-authoritative = true;
      dhcp-lease-max = 300;
      edns-packet-max = 1232;

      # Explicit upstreams; /etc/resolv.conf on this host points back at
      # dnsmasq itself, so it must not be read for upstream servers.
      no-resolv = true;
      server = upstreamDns;

      dhcp-range = [
        # OpenWrt pools: offset 100, limit 150 -> .100-.249 in each subnet.
        # Pinned static leases (s0, fry) live below the pool.
        (mkDhcpRange { tag = "main"; start = "192.168.1.100"; end = "192.168.1.249"; netmask = "255.255.248.0"; })
        (mkDhcpRange { tag = "iot"; start = "192.168.8.100"; end = "192.168.8.249"; netmask = "255.255.252.0"; })
        (mkDhcpRange { tag = "management"; start = "192.168.13.100"; end = "192.168.13.249"; netmask = "255.255.255.0"; })
      ];

      dhcp-option = [
        (mkDhcpOption "main" "router" "192.168.1.1")
        (mkDhcpOption "main" "dns-server" "192.168.1.1")
        (mkDhcpOption "iot" "router" "192.168.8.1")
        (mkDhcpOption "management" "router" "192.168.13.1")
        # IoT and management devices are untrusted and must not use this router
        # for DNS (queries are also rejected by the firewall). Suppress the
        # option entirely instead of advertising a resolver that refuses them.
        (mkDhcpSuppressedOption "iot" "dns-server")
        (mkDhcpSuppressedOption "management" "dns-server")
      ];

      dhcp-host = [
        (mkDhcpStaticLease { macs = [ "58:11:22:D9:0F:74" "58:11:22:D9:0F:75" ]; hostname = "s0"; address = "192.168.1.2"; })
        (mkDhcpStaticLease { macs = [ "70:C9:32:3D:20:02" ]; hostname = "vacuum"; address = "192.168.1.125"; })
        (mkDhcpStaticLease { macs = [ "9C:BF:0D:00:E3:56" ]; hostname = "fry"; address = "192.168.1.3"; })
        (mkDhcpStaticLease { macs = [ "C0:EE:40:A3:8C:32" ]; hostname = "eight-pod"; address = "192.168.9.14"; })
        (mkDhcpStaticLease { macs = [ "D4:43:0E:24:22:57" ]; hostname = "dog-cam"; address = "192.168.10.31"; })
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

        # Tailscale is the backup admin path to this router; access control is
        # handled by Tailscale ACLs. The NixOS firewall (and its
        # trustedInterfaces handling) is disabled here, so accept it explicitly.
        iifname "tailscale0" accept

        # LAN VLANs may talk to the router for DHCP, SSH/admin, and local diagnostics.
        # Reject DNS queries from IoT and management to this router: those
        # devices are untrusted and must not exfiltrate via DNS.
        iifname ${nftStringSet [ iotIf managementIf ]} udp dport 53 reject
        iifname ${nftStringSet [ iotIf managementIf ]} tcp dport 53 reject
        iifname @lan_ifaces accept

        # WAN input is not an exposed service surface. These rules keep the
        # router's WAN client usable and preserve OpenWrt's default WAN policy:
        # DHCPv4 replies, DHCPv6 client traffic, ping, IGMP, and the
        # ICMP/ICMPv6 needed for PMTU, errors, and IPv6 neighbor/router discovery.
        iifname "${wan}" udp sport 67 udp dport 68 accept
        iifname "${wan}" ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded, parameter-problem } accept
        iifname "${wan}" ip protocol igmp accept
        iifname "${wan}" udp dport 546 accept
        iifname "${wan}" ip6 saddr fe80::/10 icmpv6 type { mld-listener-query, mld-listener-report, mld-listener-done, mld2-listener-report } accept
        iifname "${wan}" icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } limit rate 1000/second accept
      }

      chain forward {
        type filter hook forward priority filter; policy drop;

        # Clamp TCP MSS to path MTU on WAN in both directions (OpenWrt mtu_fix).
        iifname "${wan}" tcp flags syn tcp option maxseg size set rt mtu
        oifname "${wan}" tcp flags syn tcp option maxseg size set rt mtu

        ct state established,related accept
        ct state invalid drop

        # Only the main VLAN is allowed to initiate Internet access. IoT and
        # management have no WAN forward rule, so they remain local-only unless a
        # future rule explicitly grants egress.
        iifname "${mainIf}" oifname "${wan}" accept

        # Permit forwarded ICMPv6 control/error and echo traffic required for
        # correct PMTU and NDP behavior (OpenWrt Allow-ICMPv6-Forward).
        iifname "${wan}" icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded, parameter-problem } limit rate 1000/second accept
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
        # IPv6 is routed (delegated prefix), not NATed.
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
