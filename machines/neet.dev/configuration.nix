{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
  ];

  # wt6nczjfvtba6pvjt2qtevwjpq4gcbz46bwjz4hboehgecyqmzqgwnqd.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/06f6b0bf-fe79-4b89-a549-b464c2b162a1";
  };

  networking.hostName = "neetdev";

  networking.interfaces.eno1.useDHCP = true;

  services.nginx.enable = true;
  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";

  # placeholder
  services.nginx.virtualHosts."radio.neet.space" = {
    enableACME = true;
    forceSSL = true;
  };

  services.thelounge = {
    enable = true;
    port = 9000;
    fileUploadBaseUrl = "https://files.neet.cloud/irc/";
    host = "irc.neet.dev";
    fileHost = {
      host = "files.neet.cloud";
      path = "/irc";
    };
  };

  services.murmur = {
    enable = true;
    port = 23563;
    domain = "voice.neet.space";
  };

  mailserver = {
    enable = true;
    fqdn = "mail.neet.dev";
    domains = [ "neet.space" "neet.dev" "neet.cloud" ];
    loginAccounts = {
      "jeremy@neet.dev" = {
        # nix run nixpkgs.apacheHttpd -c htpasswd -nbB "" "super secret password" | cut -d: -f2 > /hashed/password/file/location
        hashedPasswordFile = "/secret/email.password";
        aliases = [
          "zuckerberg@neet.space"
          "zuckerberg@neet.cloud"
          "zuckerberg@neet.dev"
        ];
      };
    };
    certificateScheme = 3; # use let's encrypt for certs
  };
}
