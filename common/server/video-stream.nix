{ config, pkgs, ... }:

let
  # external
  rtp-port = 8083;
  webrtc-peer-lower-port = 20000;
  webrtc-peer-upper-port = 20100;
  domain = "live.neet.space";

  # internal
  ingest-port = 8084;
  web-port = 8085;
  webrtc-port = 8086;
  toStr = builtins.toString;
in
{
  networking.firewall.allowedUDPPorts = [ rtp-port ];
  networking.firewall.allowedTCPPortRanges = [{
    from = webrtc-peer-lower-port;
    to = webrtc-peer-upper-port;
  }];
  networking.firewall.allowedUDPPortRanges = [{
    from = webrtc-peer-lower-port;
    to = webrtc-peer-upper-port;
  }];

  virtualisation.docker.enable = true;

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://localhost:${toStr web-port}";
      };
      "websocket" = {
        proxyPass = "http://localhost:${toStr webrtc-port}/websocket";
        proxyWebsockets = true;
      };
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      "lightspeed-ingest" = {
        workdir = "/var/lib/lightspeed-ingest";
        image = "projectlightspeed/ingest";
        ports = [
          "${toStr ingest-port}:8084"
        ];
        #        imageFile = pkgs.dockerTools.pullImage {
        #          imageName = "projectlightspeed/ingest";
        #          finalImageTag = "version-0.1.4";
        #          imageDigest = "sha256:9fc51833b7c27a76d26e40f092b9cec1ac1c4bfebe452e94ad3269f1f73ff2fc";
        #          sha256 = "19kxl02x0a3i6hlnsfcm49hl6qxnq2f3hfmyv1v8qdaz58f35kd5";
        #        };
      };
      "lightspeed-react" = {
        workdir = "/var/lib/lightspeed-react";
        image = "projectlightspeed/react";
        ports = [
          "${toStr web-port}:80"
        ];
        #        imageFile = pkgs.dockerTools.pullImage {
        #          imageName = "projectlightspeed/react";
        #          finalImageTag = "version-0.1.3";
        #          imageDigest = "sha256:b7c58425f1593f7b4304726b57aa399b6e216e55af9c0962c5c19333fae638b6";
        #          sha256 = "0d2jh7mr20h7dxgsp7ml7cw2qd4m8ja9rj75dpy59zyb6v0bn7js";
        #        };
      };
      "lightspeed-webrtc" = {
        workdir = "/var/lib/lightspeed-webrtc";
        image = "projectlightspeed/webrtc";
        ports = [
          "${toStr webrtc-port}:8080"
          "${toStr rtp-port}:65535/udp"
          "${toStr webrtc-peer-lower-port}-${toStr webrtc-peer-upper-port}:${toStr webrtc-peer-lower-port}-${toStr webrtc-peer-upper-port}/tcp"
          "${toStr webrtc-peer-lower-port}-${toStr webrtc-peer-upper-port}:${toStr webrtc-peer-lower-port}-${toStr webrtc-peer-upper-port}/udp"
        ];
        cmd = [
          "lightspeed-webrtc"
          "--addr=0.0.0.0"
          "--ip=${domain}"
          "--ports=${toStr webrtc-peer-lower-port}-${toStr webrtc-peer-upper-port}"
          "run"
        ];
        #        imageFile = pkgs.dockerTools.pullImage {
        #          imageName = "projectlightspeed/webrtc";
        #          finalImageTag = "version-0.1.2";
        #          imageDigest = "sha256:ddf8b3dd294485529ec11d1234a3fc38e365a53c4738998c6bc2c6930be45ecf";
        #          sha256 = "1bdy4ak99fjdphj5bsk8rp13xxmbqdhfyfab14drbyffivg9ad2i";
        #        };
      };
    };
  };
}
