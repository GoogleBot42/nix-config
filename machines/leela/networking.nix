{ config, lib, ... }:

let
  # Bench mode: leela hangs off the live gateway's LAN by its WAN port (double
  # NAT) so it can be driven over SSH, join the tailnet, and be deployed to
  # before it replaces that gateway. The live LAN is 192.168.0.0/21, which is
  # exactly the main LAN this router serves, so on the bench the main LAN
  # moves to a throwaway subnet and SSH is admitted on WAN from the live LAN.
  # Must be false for the build that goes live.
  bench = false;

  # Mono Gateway Development Kit (NXP LS1046A) port roles.
  #
  # Mainline dpaa names the ports eth0..eth4 in probe order; nothing guarantees
  # which physical port gets which name. Each role is therefore pinned to the
  # port's permanent MAC with a .link rename, so a probe reorder can never
  # swap WAN and LAN. The MACs are the board's EEPROM set as U-Boot presents
  # them (ethaddr, eth1addr..eth4addr = device-tree aliases ethernet0..4) and
  # the alias-to-socket mapping is Mono's documented one. A null MAC leaves
  # the kernel name in place, which is only acceptable on the bench.
  # The SFP+ cages are plain LAN ports until WAN (left cage, copper module;
  # the right cage's latch is the free one) and the switch trunk (right
  # cage, DAC) move onto them.
  livePorts = {
    wan = { mac = "e8:f6:d7:00:11:1a"; fallback = "eth0"; }; # RJ-45 right (ethernet2): WAN DHCP
    trunk = { mac = "e8:f6:d7:00:11:19"; fallback = "eth1"; }; # RJ-45 (ethernet1): tagged VLAN trunk
    lan1 = { mac = "e8:f6:d7:00:11:18"; fallback = "eth2"; }; # RJ-45 (ethernet0): untagged main LAN
    lan2 = { mac = "e8:f6:d7:00:11:1b"; fallback = "eth3"; }; # SFP+ left (ethernet3): untagged main LAN
    lan3 = { mac = "e8:f6:d7:00:11:1c"; fallback = "eth4"; }; # SFP+ right (ethernet4): untagged main LAN
  };

  # Bench cabling: which socket carries the live LAN into leela (by live
  # role; "wan" is the right-hand RJ-45 itself) and whether
  # that switch port delivers the main LAN tagged (VLAN id) or untagged
  # (null). On the bench that socket takes the WAN role and the cage that is
  # WAN when live takes its LAN role, so no MAC is claimed twice. Only one
  # cable may ever run between leela and the live LAN, and only into the
  # bench WAN socket: every other port is a LAN port with a DHCP server.
  benchWan = { port = "wan"; vlan = null; };

  ports =
    if bench && benchWan.port != "wan" then
      livePorts // {
        wan = livePorts.${benchWan.port};
        ${benchWan.port} = livePorts.wan;
      }
    else livePorts;
  portName = role: if ports.${role}.mac != null then role else ports.${role}.fallback;

  # Physical WAN port, and the interface that carries the WAN address (a VLAN
  # sub-interface on the bench, the port itself when live).
  wanPort = portName "wan";
  wanVlanId = if bench then benchWan.vlan else null;
  wan = if wanVlanId != null then "${wanPort}.${toString wanVlanId}" else wanPort;
  lanTrunk = portName "trunk";
  mainAccessIfs = map portName [ "lan1" "lan2" "lan3" ];

  # MACs carried over from the APU2 this router replaces. The WAN MAC keeps the
  # ISP's DHCP lease and public IP (the cable modem binds to the CPE MAC, so a
  # new MAC would need a modem reboot and would change the address); the LAN
  # MAC keeps every client's ARP entry for 192.168.1.1 valid across the swap.
  # The LAN MAC is only taken by the live build: on the bench a LAN port that
  # touches the live LAN by mistake would otherwise capture every client's
  # traffic for the real gateway.
  wanMac = "00:0d:b9:5e:94:ec";
  lanMac = "00:0d:b9:5e:94:ed";

  mainIf = "br-main";
  iotIf = "vlan-iot";
  managementIf = "vlan-management";
  cellIf = "vlan-cell";
  adminIf = "vlan-admin";
  piaIf = "vlan-pia";

  # Local DNS domain; every LAN name is <host>.<lanDomain>.
  lanDomain = "lan";

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

  # Cellular backup uplink: a UniFi 5G Backup (U5G) modem on its own VLAN so
  # it can hang off any PoE switch port in the house. The modem is not a
  # router: it is adopted by the UniFi Network controller on s0 and exposes
  # its cellular WAN to the gateway through a GRE tunnel whose inner /31 is
  # fixed in the modem firmware (modem .128, gateway .129). The outer
  # endpoints are the VLAN addresses, so the modem's address must never
  # move: the VLAN's DHCP pool is that single address.
  cell = {
    vlanId = 14;
    router = "192.168.14.1";
    modem = "192.168.14.2";
    prefixLength = 24;
    netmask = "255.255.255.0";
  };
  cellCidr = "${cell.router}/${toString cell.prefixLength}";

  # Admin VLAN: the one network that may open connections to every other
  # VLAN by address (the Infosphere SSID). Replies come back through
  # conntrack; nothing on the other VLANs can initiate towards it, and no
  # broadcast or discovery traffic crosses.
  admin = {
    vlanId = 15;
    router = "192.168.15.1";
    prefixLength = 24;
    netmask = "255.255.255.0";
    poolStart = "192.168.15.100";
    poolEnd = "192.168.15.249";
  };
  adminCidr = "${admin.router}/${toString admin.prefixLength}";

  # PIA VLAN: every client on it reaches the Internet through the PIA
  # WireGuard tunnel and nothing else. The router does not route it at all:
  # the VLAN interface lives inside the PIA VPN container (pia-vpn.lans),
  # which is the clients' DHCP server, resolver and only gateway, and whose
  # only route out is the tunnel. This host never holds an address on the
  # VLAN, so no rule here could leak it to the WAN. No LAN access either:
  # the container forwards to the tunnel or drops.
  pia = {
    vlanId = 16;
    router = "192.168.16.1";
    prefixLength = 24;
    poolOffset = 100;
    poolSize = 150;
  };
  # The bridge between this host and the VPN container. The host is only a
  # bootstrap proxy on it (PIA's API, before the tunnel exists); it must
  # never forward for it.
  vpnBridge = config.pia-vpn.bridgeName;
  vpnContainer = config.pia-vpn.vpnAddress;
  vpnProxyPort = config.pia-vpn.proxyPort;
  cellTunnelIf = "gre-cell";
  cellTunnel = {
    local = "100.127.125.129";
    remote = "100.127.125.128";
    # GRE adds 24 bytes to every packet; the modem's own gre1 is 1476 and
    # oversized packets through it are silently dropped.
    mtu = 1400;
    # Side table holding a standing default route through the tunnel so the
    # backup can be probed while idle. Failover itself (wan-failover.nix)
    # puts a default route into the main table at this metric, below the WAN
    # lease's 1024, so everything including Tailscale's own fwmark rules
    # (which pin its packets to the main table) follows it.
    table = 100;
    metric = 512;
  };
  # UniFi Network controller the modem informs to (s0). Handed out as DHCP
  # option 43 and the `unifi` DNS name on the cell VLAN because the controller
  # sits on another VLAN and cannot be found by L2 discovery from there.
  unifiController = "192.168.1.2";
  ipToHex = ip: lib.concatMapStringsSep ":"
    (octet: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString (lib.toInt octet))))
    (lib.splitString "." ip);

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

  lanIfs = [ mainIf iotIf managementIf adminIf ];
  # Every interface the Internet is reached through: masquerade, MSS clamping
  # and the forward policy treat them alike.
  wanIfs = [ wan cellTunnelIf ];
  # The modem itself needs egress on the cable WAN (eSIM provisioning,
  # UniFi Mobility, firmware) when its cellular side is not up yet.
  internetCidrs = [ mainCidr cellCidr adminCidr ];

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
  # Fixed DNS records for a pinned host, one per address. A name derived from
  # a DHCP lease hangs off exactly one lease at a time, so a host leasing on
  # several VLANs (s0 is on all three) would resolve to whichever lease was
  # renewed last, often an address the client cannot even reach. With every
  # address in a record, localise-queries answers with the one on the
  # querying client's own subnet. host-record names are not expanded, so the
  # domain is spelled out.
  mkHostRecords = { hostname ? null, addresses, ... }:
    lib.optionals (hostname != null)
      (map (address: "${hostname},${hostname}.${lanDomain},${address}") addresses);

  # Pinned addresses. Infrastructure first, then devices whose address is
  # written down elsewhere (s0's nginx, Claude project notes, dev boards).
  # One address per subnet the host may appear in; dnsmasq picks the one
  # matching the interface it asks on.
  staticLeases = [
    # s0 has an interface on every VLAN; its IoT and management addresses
    # are the ones it has held since before the gateway swap.
    { macs = [ "58:11:22:D9:0F:74" "58:11:22:D9:0F:75" ]; hostname = "s0"; addresses = [ "192.168.1.2" "192.168.8.116" "192.168.13.116" ]; }
    { macs = [ "9C:BF:0D:00:E3:56" ]; hostname = "fry"; addresses = [ "192.168.1.3" ]; }
    { macs = [ "70:C9:32:3D:20:02" ]; hostname = "vacuum"; addresses = [ "192.168.1.125" ]; }
    # eight-pod lives on the main LAN today (s0 proxies sandman to it there)
    # and keeps its IoT address for when it moves.
    { macs = [ "C0:EE:40:A3:8C:32" ]; hostname = "eight-pod"; addresses = [ "192.168.0.109" "192.168.9.14" ]; }
    { macs = [ "D4:43:0E:24:22:57" ]; hostname = "dog-cam"; addresses = [ "192.168.10.31" ]; }
    { macs = [ "90:82:C3:6E:F1:30" ]; hostname = "frame"; addresses = [ "192.168.0.125" ]; }
    # NanoKVMs
    { macs = [ "48:DA:35:6D:6D:73" ]; hostname = "kvm-6d73"; addresses = [ "192.168.0.224" ]; }
    { macs = [ "48:DA:35:6D:A9:15" ]; hostname = "kvm-a915"; addresses = [ "192.168.0.221" ]; }
    # ESP32 boards
    { macs = [ "B4:8A:0A:6C:04:24" ]; addresses = [ "192.168.0.140" ]; }
    { macs = [ "C0:4E:30:06:81:A0" ]; addresses = [ "192.168.0.241" ]; }
    { macs = [ "44:BD:8D:F6:B0:A8" ]; hostname = "luxel-f6b0a8"; addresses = [ "192.168.0.238" ]; }
    { macs = [ "C8:F0:9E:79:7E:10" ]; hostname = "luxel-797e10"; addresses = [ "192.168.0.183" ]; }
    { macs = [ "90:70:69:EA:6F:70" ]; hostname = "luxel-ea6f70"; addresses = [ "192.168.0.142" ]; }
  ];

  # DHCP/RA settings for whichever interface carries the WAN address.
  wanAddressing = {
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
  };

  nftSet = values: "{ ${lib.concatStringsSep ", " values} }";
  nftStringSet = values: "{ ${lib.concatMapStringsSep ", " (value: ''"${value}"'') values} }";
in
{
  # This machine replaces the OpenWrt APU2 gateway. The network policy is
  # intentionally unchanged; only the hardware shape and port roles move:
  #   RJ-45 right (wan): WAN DHCP
  #   RJ-45 (trunk): tagged VLAN trunk for main/iot/management/cell/admin/pia
  #   remaining RJ-45 and both SFP+ cages (lan1..lan3): untagged/native main LAN
  # The cellular backup (cell VLAN + GRE tunnel, failover in wan-failover.nix)
  # and the PIA VLAN are the additions to that policy.

  pia-vpn = {
    enable = true;
    lans.${piaIf} = {
      vlan = { parent = lanTrunk; id = pia.vlanId; };
      address = pia.router;
      inherit (pia) prefixLength;
      dhcp = { inherit (pia) poolOffset poolSize; };
    };
  };

  router.wanFailover = {
    enable = true;
    primaryInterface = wan;
    backupInterface = cellTunnelIf;
    backupGateway = cellTunnel.remote;
    backupMetric = cellTunnel.metric;
  };

  networking = {
    useDHCP = false;
    useNetworkd = true;
    dhcpcd.enable = false;
    nftables.enable = true;
    firewall.enable = lib.mkForce false;
    domain = lanDomain;
  };

  systemd.network = {
    enable = true;

    # The PIA module switches wait-online to "any interface", which its own
    # bridge would satisfy before the WAN has a lease. Everything here that
    # orders after network-online expects the WAN to be routable.
    wait-online.anyInterface = lib.mkForce false;

    # The failover watchdog owns the backup default route in the main table
    # and Tailscale owns its policy rules; a networkd restart must not sweep
    # either away as foreign.
    config.networkConfig = {
      ManageForeignRoutes = false;
      ManageForeignRoutingPolicyRules = false;
    };

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
      } // lib.optionalAttrs (!bench) { MACAddress = lanMac; };

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

      "20-${cellIf}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = cellIf;
        };
        vlanConfig.Id = cell.vlanId;
      };

      "20-${adminIf}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = adminIf;
        };
        vlanConfig.Id = admin.vlanId;
      };

      "30-${cellTunnelIf}" = {
        netdevConfig = {
          Kind = "gre";
          Name = cellTunnelIf;
          MTUBytes = cellTunnel.mtu;
        };
        tunnelConfig = {
          Local = cell.router;
          Remote = cell.modem;
          TTL = 64;
          Independent = true;
        };
      };

      "11-wan-vlan" = lib.mkIf (wanVlanId != null) {
        netdevConfig = {
          Kind = "vlan";
          Name = wan;
        };
        vlanConfig.Id = wanVlanId;
      };
    };

    networks = {
      "10-wan" = {
        matchConfig.Name = wanPort;
        networkConfig =
          if wanVlanId != null then {
            VLAN = [ wan ];
            LinkLocalAddressing = "no";
          } else wanAddressing.networkConfig;
        linkConfig.RequiredForOnline = if wanVlanId != null then "no" else "routable";
      } // lib.optionalAttrs (wanVlanId == null) (removeAttrs wanAddressing [ "networkConfig" ]);

      "11-wan-vlan" = lib.mkIf (wanVlanId != null) ({
        matchConfig.Name = wan;
        linkConfig.RequiredForOnline = "routable";
      } // wanAddressing);

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

      # The PIA VLAN is not listed: the VPN container's unit creates that
      # interface on the trunk and moves it into the container (pia-vpn.lans).
      "20-lan-trunk" = {
        matchConfig.Name = lanTrunk;
        networkConfig = {
          VLAN = [ "vlan-main-trunk" iotIf managementIf cellIf adminIf ];
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
          Domains = [ lanDomain ];
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

      "40-${cellIf}" = {
        matchConfig.Name = cellIf;
        address = [ cellCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "40-${adminIf}" = {
        matchConfig.Name = adminIf;
        address = [ adminCidr ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };

      "50-${cellTunnelIf}" = {
        matchConfig.Name = cellTunnelIf;
        address = [ "${cellTunnel.local}/31" ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
          # The kernel's loose reverse-path filter (systemd's default on every
          # interface) drops a reply arriving here whenever the main table has
          # no route to its source. That is exactly the state during a WAN
          # outage, when the backup's default lives only in the side table,
          # so the probe that decides the failover would never be answered.
          # The tunnel is point-to-point to the modem and policed by nftables.
          IPv4ReversePathFilter = "no";
        };
        # Standing default route in a side table, reached only by packets
        # explicitly bound to the tunnel (the watchdog's probes), so the
        # backup can be checked without routing anything else through it.
        routes = [
          {
            Gateway = cellTunnel.remote;
            GatewayOnLink = true;
            Table = cellTunnel.table;
          }
        ];
        routingPolicyRules = [
          {
            OutgoingInterface = cellTunnelIf;
            Table = cellTunnel.table;
            # Below Tailscale's rules (5210-5270) and above main (32766).
            Priority = 5300;
          }
        ];
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
      interface = lanIfs ++ [ cellIf ];
      except-interface = wanIfs;
      bind-dynamic = true;
      domain-needed = true;
      bogus-priv = true;
      localise-queries = true;
      stop-dns-rebind = true;
      rebind-localhost-ok = true;
      # Our own zone publishes tailnet (100.64/10) addresses for s0's services,
      # which rebind protection would otherwise swallow for LAN clients.
      rebind-domain-ok = [ "/neet.dev/" ];
      # Only answer DNS for directly attached subnets (OpenWrt localservice).
      local-service = true;
      local = "/${lanDomain}/";
      domain = lanDomain;
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
        # One address: the GRE tunnel's outer endpoint must not move.
        (mkDhcpRange { tag = "cell"; start = cell.modem; end = cell.modem; netmask = cell.netmask; })
        (mkDhcpRange { tag = "admin"; start = admin.poolStart; end = admin.poolEnd; netmask = admin.netmask; })
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
        (mkDhcpOption "cell" "router" cell.router)
        (mkDhcpOption "cell" "dns-server" cell.router)
        (mkDhcpOption "admin" "router" admin.router)
        (mkDhcpOption "admin" "dns-server" admin.router)
        # UniFi vendor option: sub-option 1 (length 4) = controller IPv4.
        "tag:cell,43,01:04:${ipToHex unifiController}"
      ];

      # /etc/hosts maps this host's own name to 127.0.0.2 (NixOS does that
      # whenever networking.domain is set), and dnsmasq would hand that
      # loopback address to every LAN client asking for leela.lan. Ignore
      # /etc/hosts and answer for the router by name explicitly.
      no-hosts = true;
      host-record = [
        "${config.networking.hostName},${config.networking.hostName}.${lanDomain},${main.router}"
        # UniFi devices also look the controller up by the bare name `unifi`.
        "unifi,unifi.${lanDomain},${unifiController}"
      ] ++ lib.concatMap mkHostRecords staticLeases;

      dhcp-host = map mkDhcpStaticLease staticLeases;
    };
  };

  networking.nftables.tables.gateway = {
    family = "inet";
    content = ''
      set lan_ifaces {
        type ifname
        elements = ${nftStringSet lanIfs}
      }

      set wan_ifaces {
        type ifname
        elements = ${nftStringSet wanIfs}
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
        # node_exporter is for the tailnet scraper and the trusted LAN only.
        iifname ${nftStringSet [ iotIf managementIf ]} tcp dport 9100 reject
        iifname @lan_ifaces accept

        # The cellular modem is a vendor appliance, not a LAN client: DHCP,
        # DNS, ping and the GRE tunnel from its fixed address, nothing else.
        iifname "${cellIf}" ip saddr ${cell.modem} ip protocol gre accept
        iifname "${cellIf}" udp dport { 53, 67 } accept
        iifname "${cellIf}" tcp dport 53 accept
        iifname "${cellIf}" ip protocol icmp accept
        # Inside the tunnel the router is a plain client of the modem's NAT.
        iifname "${cellTunnelIf}" ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded, parameter-problem } accept

        # The PIA VPN container bootstraps through the proxy on the bridge
        # (PIA's API has to be reached before the tunnel exists). Only that
        # container, only that port.
        iifname "${vpnBridge}" ip saddr ${vpnContainer} tcp dport ${toString vpnProxyPort} accept

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
        # On the tunnel this is what keeps TCP working at its smaller MTU.
        iifname @wan_ifaces tcp flags syn tcp option maxseg size set rt mtu
        oifname @wan_ifaces tcp flags syn tcp option maxseg size set rt mtu

        ct state established,related accept
        ct state invalid drop

        # The VPN bridge is never forwarded, in either direction: the VPN
        # container is the only gateway for anything behind it, and the PIA
        # VLAN is not even an interface of this host. Stated before every
        # accept so no later rule can widen it.
        iifname "${vpnBridge}" drop
        oifname "${vpnBridge}" drop

        # Only the main VLAN is allowed to initiate Internet access. IoT and
        # management have no WAN forward rule, so they remain local-only unless a
        # future rule explicitly grants egress. Which WAN carries it is decided
        # by routing (the failover watchdog), not here.
        iifname ${nftStringSet [ mainIf adminIf ]} oifname @wan_ifaces accept

        # The admin VLAN may open connections to any other VLAN by address.
        # Only replies flow back (conntrack); nothing initiates towards it.
        iifname "${adminIf}" oifname ${nftStringSet [ mainIf iotIf managementIf cellIf ]} accept

        # The modem's own egress (eSIM, UniFi Mobility, firmware) goes out the
        # cable WAN; its tunnel is for LAN traffic, not for the modem itself.
        iifname "${cellIf}" ip saddr ${cell.modem} oifname "${wan}" accept
        # Adoption and management by the UniFi controller on s0: inform
        # (8080), STUN (3478) and the speed-test port (6789). s0 answers on its
        # main-LAN address and holds a dynamic lease on the management VLAN,
        # so both are reachable for these ports and nothing else.
        iifname "${cellIf}" ip saddr ${cell.modem} oifname "${mainIf}" ip daddr ${unifiController} tcp dport { 8080, 6789 } accept
        iifname "${cellIf}" ip saddr ${cell.modem} oifname "${mainIf}" ip daddr ${unifiController} udp dport 3478 accept
        iifname "${cellIf}" ip saddr ${cell.modem} oifname "${managementIf}" tcp dport { 8080, 6789 } accept
        iifname "${cellIf}" ip saddr ${cell.modem} oifname "${managementIf}" udp dport 3478 accept
        # The trusted LAN may reach the modem (SSH, its screen's web pages).
        iifname "${mainIf}" oifname "${cellIf}" accept

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
        # IPv6 is routed (delegated prefix), not NATed. Inside the tunnel the
        # modem NATs again to the carrier address.
        oifname ${nftStringSet wanIfs} ip saddr @internet4_subnets masquerade
      }
    '';
  };

  assertions = [
    {
      assertion = builtins.length (lib.unique [ 2 4 5 cell.vlanId admin.vlanId pia.vlanId ]) == 6;
      message = "VLAN ids must be distinct.";
    }
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
