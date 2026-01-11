{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  nix.gc.automatic = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    system76-keyboard-configurator
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1"; # nginx proxy
    port = 12831;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://localhost:${toString config.services.ollama.port}";
    };
  };

  # nginx
  services.nginx = {
    enable = true;
    openFirewall = false; # All nginx services are internal
    virtualHosts =
      let
        mkHost = external: config:
          {
            ${external} = {
              useACMEHost = "fry.neet.dev"; # Use wildcard cert
              forceSSL = true;
              locations."/" = config;
            };
          };
        mkVirtualHost = external: internal:
          mkHost external {
            proxyPass = internal;
            proxyWebsockets = true;
          };
      in
      lib.mkMerge [
        (mkVirtualHost "chat.fry.neet.dev" "http://localhost:${toString config.services.open-webui.port}")
      ];
  };

  # Get wildcard cert
  security.acme.certs."fry.neet.dev" = {
    dnsProvider = "digitalocean";
    credentialsFile = "/run/agenix/digitalocean-dns-credentials";
    extraDomainNames = [ "*.fry.neet.dev" ];
    group = "nginx";
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false; # sadly this erroneously fails
  };
  age.secrets.digitalocean-dns-credentials.file = ../../secrets/digitalocean-dns-credentials.age;
}
