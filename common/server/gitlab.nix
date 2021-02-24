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
    };
    pagesExtraArgs = [ "-listen-proxy" "127.0.0.1:8090" ];
  };

  services.nginx.virtualHosts = {
    "git.neet.dev" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
    };
  };
}
