{ config, ... }:

{
  services.nsd = let
    self = "142.4.210.222";
    secondary = "167.114.154.31";
  in {
    enable = true;
    interfaces = [ "0.0.0.0" ];
    roundRobin = true;
    ipTransparent = true;
    zones.neet = rec {
      provideXFR = [ "${secondary} NOKEY" ];
      notify = provideXFR;
      children = {
        "neet.dev.".data = ''
$TTL 300
@   IN  SOA     ns1.neet.dev. contact.neet.dev. (
        2011072000  ;Serial
        300         ;Refresh
        300         ;Retry
        604800      ;Expire
        300         ;Minimum TTL
)

@            IN  NS          ns1.neet.dev.
@            IN  NS          ns2.neet.dev.

@            IN  A           ${self}
www          IN  A           ${self}
irc          IN  A           ${self}
wiki         IN  A           ${self}
ns1          IN  A           ${self}
ns2          IN  A           167.114.154.31
ragnarok     IN  A           155.138.219.146
coder        IN  A           ${self}
git          IN  A           ${self}

@            IN  TXT         "rizon_vhost=Googlebot"
ownercheck   IN  TXT         "dc97b3fd"
        '';
        "neet.space.".data = ''
$TTL 300
@   IN  SOA     ns1.neet.dev. contact.neet.dev. (
        2011071017  ;Serial
        300         ;Refresh
        300         ;Retry
        604800      ;Expire
        300         ;Minimum TTL
)

@                  IN  NS          ns1.neet.dev.
@                  IN  NS          ns2.neet.dev.

@                  IN  A           ${self}
www                IN  A           ${self}
voice              IN  A           ${self}
stream             IN  A           ${self}
radio              IN  A           ${self}
tube               IN  A           ${self}
sock.tube          IN  A           ${self}
mural              IN  A           ${self}

_minecraft._tcp    IN  SRV         0 5 23589 neet.space.
_mumble._tcp       IN  SRV         0 5 23563 voice.neet.space.
_mumble._tcp.voice IN  SRV         0 5 23563 voice.neet.space.

@                  IN  TXT         "rizon_vhost=Googlebot"
ownercheck         IN  TXT         "dc97b3fd"
        '';
        "neet.cloud.".data = ''
$TTL 300
@   IN  SOA     ns1.neet.dev. contact.neet.dev. (
        2011071011  ;Serial
        300         ;Refresh
        300         ;Retry
        604800      ;Expire
        300         ;Minimum TTL
)

@            IN  NS          ns1.neet.dev.
@            IN  NS          ns2.neet.dev.

@            IN  A           ${self}
www          IN  A           ${self}
paste        IN  A           ${self}
globie-info  IN  A           ${self}
files        IN  A           ${self}

ownercheck   IN  TXT         "dc97b3fd"
        '';
      };
    };
  };
}
