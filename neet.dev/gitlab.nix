{ config, pkgs, ... }:

{
  services.gitlab = {
    enable = true;
    databasePasswordFile = "/var/keys/gitlab/db_password";
    initialRootPasswordFile = "/var/keys/gitlab/root_password";
    https = true;
    host = "git.neet.dev";
    port = 443;
    user = "git";
    group = "git";
    databaseUsername = "git";
    smtp = {
      enable = true;
      address = "localhost";
      port = 25;
    };
    secrets = {
      dbFile = "/var/keys/gitlab/db";
      secretFile = "/var/keys/gitlab/secret";
      otpFile = "/var/keys/gitlab/otp";
      jwsFile = "/var/keys/gitlab/jws";
    };
    extraConfig = {
      gitlab = {
        email_from = "gitlab-no-reply@neet.dev";
        email_display_name = "neet.dev GitLab";
        email_reply_to = "gitlab-no-reply@neet.dev";
      };
      pages = {
        enabled = true;
        host = "pages.neet.dev";
        port = 443;
        https = true;
      };
    };
    pagesExtraArgs = [ "-listen-proxy" "127.0.0.1:8090" ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  services.gitlab-runner = {
#    enable = true;
    enable = false;
    services = {
      # runner for building in docker via host's nix-daemon
      # nix store will be readable in runner, might be insecure
      nix = {
        registrationConfigFile = "/run/secrets/gitlab-runner-registration";
        dockerImage = "alpine";
        dockerVolumes = [
          "/nix/store:/nix/store:ro"
          "/nix/var/nix/db:/nix/var/nix/db:ro"
          "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
        ];
        dockerDisableCache = true;
        preBuildScript = pkgs.writeScript "setup-container" ''
          mkdir -p -m 0755 /nix/var/log/nix/drvs
          mkdir -p -m 0755 /nix/var/nix/gcroots
          mkdir -p -m 0755 /nix/var/nix/profiles
          mkdir -p -m 0755 /nix/var/nix/temproots
          mkdir -p -m 0755 /nix/var/nix/userpool
          mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
          mkdir -p -m 1777 /nix/var/nix/profiles/per-user
          mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
          mkdir -p -m 0700 "$HOME/.nix-defexpr"

          . ${pkgs.nix}/etc/profile.d/nix.sh

          ${pkgs.nix}/bin/nix-env -i ${builtins.concatStringsSep " " (with pkgs; [ nix cacert git openssh ])}

          ${pkgs.nix}/bin/nix-channel --add https://nixos.org/channels/nixpkgs-unstable
          ${pkgs.nix}/bin/nix-channel --update nixpkgs
        '';
        environmentVariables = {
          ENV = "/etc/profile";
          USER = "root";
          NIX_REMOTE = "daemon";
          PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
          NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
        };
        tagList = [ "nix" ];
      };
      # runner for building docker images
      docker-images = {
        registrationConfigFile = "/run/secrets/gitlab-runner-registration";
        dockerImage = "docker:stable";
        dockerVolumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
        tagList = [ "docker-images" ];
      };
      # runner for everything else
      default = {
        registrationConfigFile = "/run/secrets/gitlab-runner-registration";
        dockerImage = "debian:stable";
      };
    };    
  };

  services.nginx.virtualHosts = {
    "git.neet.dev" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
    };
    "*.pages.neet.dev" = {
      forceSSL = true;
      useACMEHost = "pages.neet.dev";
      locations."/".proxyPass = "http://localhost:8090";
    };
  };
}
