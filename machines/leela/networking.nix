{ lib, ... }:

let
  # Bench mode: leela hangs off the live gateway's LAN by its WAN port (double
  # NAT) so it can be driven over SSH, join the tailnet, and be deployed to
  # before it replaces that gateway. The live LAN is 192.168.0.0/21, which is
  # exactly the main LAN this router serves, so on the bench the main LAN
  # moves to a throwaway subnet and SSH is admitted on WAN from the live LAN.
  # Must be false for the build that goes live.
  bench = true;

  # Mono Gateway Development Kit (NXP LS1046A) port roles.
  #
  # Mainline dpaa names the ports eth0..eth4 in probe order; nothing guarantees
  # which physical port gets which name. Each role is therefore pinned to the
  # port's permanent MAC (U-Boot: printenv ethaddr eth1addr eth2addr eth3addr
  # eth4addr; or `ip link` on the first boot) with a .link rename, so a probe
  # reorder can never swap WAN and LAN. A null MAC leaves the kernel name in
  # place, which is only acceptable on the bench, never for the live gateway.
  ports = {
    wan = { mac = null; fallback = "eth0"; }; # SFP+ 1: WAN DHCP
    trunk = { mac = null; fallback = "eth1"; }; # SFP+ 2: tagged VLAN trunk
    lan1 = { mac = null; fallback = "eth2"; }; # RJ-45: untagged main LAN
    lan2 = { mac = null; fallback = "eth3"; }; # RJ-45: untagged main LAN
    lan3 = { mac = null; fallback = "eth4"; }; # RJ-45: untagged main LAN
  };
  portName = role: if ports.${role}.mac != null then role else ports.${role}.fallback;

  wan = portName "wan";
  lanTrunk = portName "trunk";
  mainAccessIfs = map portName [ "lan1" "lan2" "lan3" ];

  # MACs carried over from the APU2 this router replaces. The WAN MAC keeps the
  # ISP's DHCP lease and public IP (the cable modem binds to the CPE MAC, so a
  # new MAC would need a modem reboot and would change the address); the LAN
  # MAC keeps every client's ARP entry for 192.168.1.1 valid across the swap.
  wanMac = "00:0d:b9:5e:94:ec";
  lanMac = "00:0d:b9:5e:94:ed";

  mainIf = "br-main";
  iotIf = "vlan-iot";
  managementIf = "vlan-management";

  # The main LAN is 192.168.0.0/21 with the router at 192.168.1.1. The DHCP
  # pool is .0.100-.0.249 (offsets from the network address, as OpenWrt
  # computed them); s0/fry and the other pinned leases sit outside it.
  main =
    if bench then {
      router = "10.99.0.1";
      prefixLength = 24;
      netmask = "255.255.255.0";
      poolStart = "10.99.0.100";
      poolEnd = "10.99.0.249";
    } else {
      router = "192.168.1.1";
      prefixLength = 21;
      netmask = "255.255.248.0";
      poolStart = "192.168.0.100";
      poolEnd = "192.168.0.249";
    };
  mainCidr = "${main.router}/${toString main.prefixLength}";
  iotCidr = "192.168.8.1/22";
  managementCidr = "192.168.13.1/24";

  # Main-LAN IPv6 (delegated prefix + SLAAC) is a behaviour change from the
  # OpenWrt gateway, which never announced a prefix on any LAN. Kept off so the
  # swap changes nothing clients can see; flip on as a separate change.
  mainLanIpv6 = false;

  # Sources allowed to SSH to the router over WAN. Only ever non-empty on the
  # bench, where WAN faces the live LAN; the live gateway exposes no WAN service.
  wanAdminSources = lib.optionals bench [ "192.168.0.0/21" ];

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
  # appears in multiple dhcp-host lines. One address per subnet the host may
  # appear in; dnsmasq picks the one matching the interface it asks on.
  mkDhcpStaticLease = { macs, hostname ? null, addresses }:
    lib.concatStringsSep "," (macs ++ lib.optional (hostname != null) hostname ++ addresses);

  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  nftStringSet = values: "{ ${lib.concatMapStringsSep ", " (value: ''"${value}"'') values} }";
in
{
  # This machine replaces the OpenWrt APU2 gateway. The network policy is
  # intentionally unchanged; only the hardware shape and port roles move:
  #   SFP+ 1 (wan): WAN DHCP
  #   SFP+ 2 (trunk): tagged VLAN trunk for main/iot/management
  #   RJ-45 ports (lan1..lan3): untagged/native main LAN

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

    links = lib.mapAttrs'
      (role: port: lib.nameValuePair "10-${role}" {
        matchConfig =
          if port.mac != null
          then { PermanentMACAddress = port.mac; }
          else { OriginalName = port.fallback; };
        linkConfig =
          lib.optionalAttrs (port.mac != null) { Name = role; }
          // lib.optionalAttrs (role == "wan") { MACAddress = wanMac; };
      })
      (lib.filterAttrs (role: port: port.mac != null || role == "wan") ports);

    netdevs = {
      "10-${mainIf}".netdevConfig = {
        Kind = "bridge";
        Name = mainIf;
        MACAddress = lanMac;
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
        # Same client identity the APU2's udhcpc presented (MAC-based client
        # id, broadcast flag, no hostname) so the ISP sees the same client.
        # On the bench the hostname is sent so leela.lan resolves on the live
        # LAN without having to hunt for its address.
        dhcpV4Config = {
          ClientIdentifier = "mac";
          RequestBroadcast = true;
          SendHostname = bench;
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
        } // lib.optionalAttrs mainLanIpv6 {
          # Take a prefix from the WAN DHCPv6 prefix delegation and announce it
          # via router advertisements. Clients get SLAAC addresses and are
          # pointed at this router's link-local address (dnsmasq) for DNS.
          DHCPPrefixDelegation = true;
          IPv6SendRA = true;
        };
        ipv6SendRAConfig = lib.optionalAttrs mainLanIpv6 {
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
      # Also makes dnsmasq ACK a renewal for an in-pool address it has no
      # lease for, so clients keep their addresses across the gateway swap
      # even where the lease file was not carried over.
      dhcp-authoritative = true;
      dhcp-lease-max = 300;
      edns-packet-max = 1232;

      # Explicit upstreams; /etc/resolv.conf on this host points back at
      # dnsmasq itself, so it must not be read for upstream servers.
      no-resolv = true;
      server = upstreamDns;

      dhcp-range = [
        (mkDhcpRange { tag = "main"; start = main.poolStart; end = main.poolEnd; netmask = main.netmask; })
        (mkDhcpRange { tag = "iot"; start = "192.168.8.100"; end = "192.168.8.249"; netmask = "255.255.252.0"; })
        (mkDhcpRange { tag = "management"; start = "192.168.13.100"; end = "192.168.13.249"; netmask = "255.255.255.0"; })
      ];

      dhcp-option = [
        (mkDhcpOption "main" "router" main.router)
        (mkDhcpOption "main" "dns-server" main.router)
        (mkDhcpOption "iot" "router" "192.168.8.1")
        (mkDhcpOption "management" "router" "192.168.13.1")
        # IoT and management devices are untrusted and must not use this router
        # for DNS (queries are also rejected by the firewall). Suppress the
        # option entirely instead of advertising a resolver that refuses them.
        (mkDhcpSuppressedOption "iot" "dns-server")
        (mkDhcpSuppressedOption "management" "dns-server")
      ];

      # Pinned addresses. Infrastructure first, then devices whose address is
      # written down elsewhere (s0's nginx, Claude project notes, dev boards).
      dhcp-host = [
        (mkDhcpStaticLease { macs = [ "58:11:22:D9:0F:74" "58:11:22:D9:0F:75" ]; hostname = "s0"; addresses = [ "192.168.1.2" ]; })
        (mkDhcpStaticLease { macs = [ "9C:BF:0D:00:E3:56" ]; hostname = "fry"; addresses = [ "192.168.1.3" ]; })
        (mkDhcpStaticLease { macs = [ "70:C9:32:3D:20:02" ]; hostname = "vacuum"; addresses = [ "192.168.1.125" ]; })
        # eight-pod lives on the main LAN today (s0 proxies sandman to it there)
        # and keeps its IoT address for when it moves.
        (mkDhcpStaticLease { macs = [ "C0:EE:40:A3:8C:32" ]; hostname = "eight-pod"; addresses = [ "192.168.0.109" "192.168.9.14" ]; })
        (mkDhcpStaticLease { macs = [ "D4:43:0E:24:22:57" ]; hostname = "dog-cam"; addresses = [ "192.168.10.31" ]; })
        (mkDhcpStaticLease { macs = [ "90:82:C3:6E:F1:30" ]; hostname = "frame"; addresses = [ "192.168.0.125" ]; })
        # NanoKVMs
        (mkDhcpStaticLease { macs = [ "48:DA:35:6D:6D:73" ]; hostname = "kvm-6d73"; addresses = [ "192.168.0.224" ]; })
        (mkDhcpStaticLease { macs = [ "48:DA:35:6D:A9:15" ]; hostname = "kvm-a915"; addresses = [ "192.168.0.221" ]; })
        # ESP32 boards
        (mkDhcpStaticLease { macs = [ "B4:8A:0A:6C:04:24" ]; addresses = [ "192.168.0.140" ]; })
        (mkDhcpStaticLease { macs = [ "C0:4E:30:06:81:A0" ]; addresses = [ "192.168.0.241" ]; })
        (mkDhcpStaticLease { macs = [ "44:BD:8D:F6:B0:A8" ]; hostname = "luxel-f6b0a8"; addresses = [ "192.168.0.238" ]; })
        (mkDhcpStaticLease { macs = [ "C8:F0:9E:79:7E:10" ]; hostname = "luxel-797e10"; addresses = [ "192.168.0.183" ]; })
        (mkDhcpStaticLease { macs = [ "90:70:69:EA:6F:70" ]; hostname = "luxel-ea6f70"; addresses = [ "192.168.0.142" ]; })
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

        ${lib.optionalString (wanAdminSources != [ ]) ''
          iifname "${wan}" ip saddr ${nftSet wanAdminSources} tcp dport 22 accept
        ''}
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
    {
      assertion = bench || wanAdminSources == [ ];
      message = "The live gateway must not accept SSH on WAN.";
    }
  ];
}
