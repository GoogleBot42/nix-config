{ lib, config, ... }:

# configures icecast to only accept source from localhost
# to a audio optimized stream on services.icecast.mount
# made available via nginx for http access on
# https://host/mount

let
  cfg = config.services.icecast;
in {
  options.services.icecast = {
    mount = lib.mkOption {
      type = lib.types.str;
      example = "stream.mp3";
    };
  };

  config = lib.mkIf cfg.enable {
    services.icecast = {
      listen.address = "127.0.0.1";
      admin.password = "hackme";
      extraConf = ''
        <authentication>
          <source-password>hackme</source-password>
        </authentication>
        <http-headers>
          <header type="cors" name="Access-Control-Allow-Origin" />
        </http-headers>
        <mount type="normal">
          <mount-name>/${cfg.mount}</mount-name>
          <max-listeners>20</max-listeners>
          <burst-size>65536</burst-size>
          <hidden>false</hidden>
          <public>false</public>
        </mount>
      '';
    };
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/${cfg.mount}" = {
        proxyPass = "http://localhost:${toString cfg.listen.port}/${cfg.mount}";
      };
    };
  };
}
