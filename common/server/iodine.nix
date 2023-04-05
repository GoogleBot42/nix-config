{ config, pkgs, lib, ... }:

let
  cfg = config.services.iodine.server;
in
{
  config = lib.mkIf cfg.enable {
    # iodine DNS-based vpn
    services.iodine.server = {
      ip = "192.168.99.1";
      domain = "tun.neet.dev";
      passwordFile = "/run/agenix/iodine";
    };
    age.secrets.iodine.file = ../../secrets/iodine.age;
    networking.firewall.allowedUDPPorts = [ 53 ];

    networking.nat.internalInterfaces = [
      "dns0" # iodine
    ];
  };
}
