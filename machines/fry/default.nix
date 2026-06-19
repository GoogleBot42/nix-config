{ config, pkgs, lib, ... }:

let
  hermesWorkspaceIp = config.sandboxed-workspace.workspaces.hermes.ip;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  nix.gc.automatic = lib.mkForce false;

  # Upstream interface for sandbox networking (NAT)
  networking.sandbox.upstreamInterface = lib.mkDefault "enp191s0";

  # Enable sandboxed workspace
  sandboxed-workspace = {
    enable = true;
    workspaces.test-incus = {
      type = "incus";
      autoStart = true;
      config = ./workspaces/test-container.nix;
      ip = "192.168.83.90";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0SNSy/MdW38NqKzLr1SG8WKrs8XkrqibacaJtJPzgW";
    };
    workspaces.hermes = {
      type = "incus";
      autoStart = true;
      config = ./workspaces/hermes;
      ip = "192.168.83.91";
      extraMounts = {
        hermes-state = {
          hostPath = "/home/googlebot/sandboxed/hermes/hermes-state";
          containerPath = "/var/lib/hermes";
        };
        hermes-env = {
          hostPath = "/run/agenix/hermes-env";
          containerPath = "/etc/hermes-env";
          createHostPath = false; # managed by agenix
          shift = false; # /run is tmpfs; idmapping not supported
        };
        ntfy-token = {
          hostPath = "/run/agenix/ntfy-token";
          containerPath = "/etc/ntfy-token";
          createHostPath = false; # managed by agenix
          shift = false; # /run is tmpfs; idmapping not supported
        };
        agent-email-pw = {
          hostPath = "/run/agenix/agent-email-pw";
          containerPath = "/etc/agent-email-pw";
          createHostPath = false; # managed by agenix
          shift = false; # /run is tmpfs; idmapping not supported
        };
      };
    };
  };
  # Bind-mounted into the hermes workspace with shift=false (tmpfs can't be
  # idmapped). Mode 0444 lets systemd inside the container read it via the
  # "other" bits — the file shows up as nobody:nogroup over an un-shifted mount.
  age.secrets.hermes-env = {
    file = ../../secrets/hermes-env.age;
    mode = "0444";
  };
  age.secrets.ntfy-token = {
    file = ../../secrets/ntfy-token.age;
    mode = "0444";
  };
  age.secrets.agent-email-pw = {
    file = ../../secrets/agent-email-pw.age;
    mode = "0444";
  };
  age.secrets.attic-netrc.mode = "0444";

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
    environmentFile = "/run/agenix/hermes-env";
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      ENABLE_FORWARD_USER_INFO_HEADERS = "True";
      OLLAMA_API_BASE_URL = "http://localhost:${toString config.services.ollama.port}";
      OPENAI_API_BASE_URL = "http://${hermesWorkspaceIp}:8642/v1";
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
        (mkVirtualHost "hooks.fry.neet.dev" "http://${hermesWorkspaceIp}:8644")
      ];
  };

}
