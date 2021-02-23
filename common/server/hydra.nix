{ config, pkgs, ... }:

let
  domain = "hydra.neet.dev";
  port = 3000;
  notifyEmail = "hydra@neet.dev";
in
{
    # the lounge client
  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString port}";
    };
  };

  services.hydra = {
    enable = true;
    port = 3000;
    hydraURL = "https://${domain}";
    useSubstitutes = true;
    notificationSender = notifyEmail;
    buildMachinesFiles = [];
  };
}