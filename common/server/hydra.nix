{ config, pkgs, ... }:

let
  domain = "hydra.neet.dev";
  port = 3000;
  notifyEmail = "hydra@neet.dev";
in
{
  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString port}";
    };
  };

  services.hydra = {
    enable = true;
    inherit port;
    hydraURL = "https://${domain}";
    useSubstitutes = true;
    notificationSender = notifyEmail;
    buildMachinesFiles = [ ];
  };
}
