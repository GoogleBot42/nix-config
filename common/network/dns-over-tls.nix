{ config, lib, ... }:

# A caching forwarder that speaks DNS over TLS to a fixed set of public
# resolvers (unbound), so that nobody on the path (the ISP, a VPN exit, the
# resolvers' transit) reads queries in the clear and only the operators named
# below see them at all. Whoever enables it decides where it listens and who
# may ask; the upstreams and the transport are the same on every host.

with lib;

let
  cfg = config.dnsOverTls;
in
{
  options.dnsOverTls = {
    enable = mkEnableOption "a local DNS-over-TLS forwarder (unbound)";

    listenAddresses = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.1" ];
      description = "Addresses the forwarder answers on.";
    };

    port = mkOption {
      type = types.port;
      default = 53;
      description = "Port the forwarder answers on, on every listen address.";
    };

    allowFrom = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.0/8" ];
      description = "Networks (CIDR) whose queries are answered; everything else is refused.";
    };

    upstreams = mkOption {
      type = types.listOf (types.submodule {
        options = {
          address = mkOption { type = types.str; description = "IPv4 address of the resolver"; };
          name = mkOption { type = types.str; description = "Name on the resolver's TLS certificate"; };
        };
      });
      default = [
        { address = "9.9.9.9"; name = "dns.quad9.net"; }
        { address = "149.112.112.112"; name = "dns.quad9.net"; }
        { address = "1.1.1.1"; name = "cloudflare-dns.com"; }
        { address = "1.0.0.1"; name = "cloudflare-dns.com"; }
      ];
      description = ''
        Resolvers asked over TLS on port 853, authenticated by certificate name.
        unbound spreads queries over them by measured response time and stops
        using one that times out, so a single bad resolver costs a retry, not
        a stall.
      '';
    };

    privateAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "192.168.0.0/16" "10.0.0.0/8" ];
      description = ''
        Address ranges removed from upstream answers (DNS rebinding
        protection). Leave empty where a resolver in front of this one already
        filters, or where names legitimately resolve to private addresses.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.unbound = {
      enable = true;
      # The hosts that run this have their own idea of how they resolve (a
      # dnsmasq in front, or an explicit nameserver): never rewrite theirs.
      resolveLocalQueries = false;
      settings = {
        server = {
          interface = map (a: "${a}@${toString cfg.port}") cfg.listenAddresses;
          access-control = [ "0.0.0.0/0 refuse" "::0/0 refuse" ] ++ map (n: "${n} allow") cfg.allowFrom;
          # The upstreams are reached over IPv4 only; an IPv6 attempt would
          # just time out on a host whose uplink (or tunnel) has none.
          do-ip6 = false;
          qname-minimisation = true;
          harden-glue = true;
          harden-dnssec-stripped = true;
          aggressive-nsec = true;
          prefetch = true;
          # Small enough to pass any path without fragmentation.
          edns-buffer-size = 1232;
          hide-identity = true;
          hide-version = true;
          private-address = cfg.privateAddresses;
        };
        forward-zone = [{
          name = ".";
          forward-tls-upstream = true;
          forward-addr = map (u: "${u.address}@853#${u.name}") cfg.upstreams;
        }];
      };
    };
  };
}
