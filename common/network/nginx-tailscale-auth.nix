# Replaces nixpkgs' services/web-servers/nginx/tailscale-auth.nix so nginx
# virtual hosts can admit Tailscale nodes by ACL tag. Every node in this
# tailnet is tagged, and upstream nginx-auth rejects all tagged nodes; the
# patched daemon (overlays/default.nix) checks an allowlist instead.
{ config, lib, ... }:

let
  inherit (lib)
    concatStringsSep
    genAttrs
    hasPrefix
    mkAliasOptionModule
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;
  cfg = config.services.nginx.tailscaleAuth;
  cfgAuth = config.services.tailscaleAuth;

  normalizeTag = tag: if hasPrefix "tag:" tag then tag else "tag:${tag}";

  # Exact-match path so it cannot shadow application routes such as /auth.
  authPath = "/.tailscale-auth";
in
{
  imports = [
    (mkAliasOptionModule
      [ "services" "nginx" "tailscaleAuth" "package" ]
      [ "services" "tailscaleAuth" "package" ]
    )
    (mkAliasOptionModule
      [ "services" "nginx" "tailscaleAuth" "user" ]
      [ "services" "tailscaleAuth" "user" ]
    )
    (mkAliasOptionModule
      [ "services" "nginx" "tailscaleAuth" "group" ]
      [ "services" "tailscaleAuth" "group" ]
    )
    (mkAliasOptionModule
      [ "services" "nginx" "tailscaleAuth" "socketPath" ]
      [ "services" "tailscaleAuth" "socketPath" ]
    )
  ];

  options.services.nginx.tailscaleAuth = {
    enable = mkEnableOption ''
      tailscale.nginx-auth. Every tailscaleOnly virtual host is put behind it
      unless that host sets tailscaleAuth.enable = false
    '';

    expectedTailnet = mkOption {
      default = "";
      type = types.nullOr types.str;
      example = "tailnet012345.ts.net";
      description = ''
        If you want to prevent node sharing from allowing users to access services
        across tailnets, declare your expected tailnet domain here.
      '';
    };

    defaultAllowedTags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "workstation" "server" ];
      description = ''
        Tailscale ACL tags admitted by every protected virtual host that does
        not set its own tailscaleAuth.allowedTags. Bare names are normalized
        to "tag:<name>". If empty, only untagged devices are admitted.
      '';
    };

    virtualHosts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional nginx virtual hosts to put behind tailscale.nginx-auth.
      '';
    };
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options.tailscaleAuth = {
        enable = mkEnableOption "tailscale.nginx-auth for this virtual host";

        allowedTags = mkOption {
          type = types.listOf types.str;
          default = cfg.defaultAllowedTags;
          defaultText = lib.literalExpression "config.services.nginx.tailscaleAuth.defaultAllowedTags";
          example = [ "workstation" "claude" ];
          description = ''
            Tailscale ACL tags admitted by this virtual host; a node needs at
            least one. Bare names are normalized to "tag:<name>". If empty,
            only untagged devices are admitted.
          '';
        };
      };

      config = lib.mkMerge [
        { tailscaleAuth.enable = mkDefault (cfg.enable && config.tailscaleOnly); }
        (mkIf config.tailscaleAuth.enable {
          locations."= ${authPath}".extraConfig = ''
            internal;
            auth_request off;

            proxy_pass http://unix:${cfgAuth.socketPath};
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";

            # Upstream uses $http_host here, but we are using gixy to check nginx configurations
            # gixy wants us to use $host: https://github.com/yandex/gixy/blob/master/docs/en/plugins/hostspoofing.md
            proxy_set_header Host $host;
            proxy_set_header Remote-Addr $remote_addr;
            proxy_set_header Remote-Port $remote_port;
            proxy_set_header Original-URI $request_uri;
            proxy_set_header X-Scheme                $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
            ${optionalString (cfg.expectedTailnet != null && cfg.expectedTailnet != "") ''proxy_set_header Expected-Tailnet "${cfg.expectedTailnet}";''}
            ${optionalString (config.tailscaleAuth.allowedTags != [ ]) ''proxy_set_header Allowed-Tailscale-Tags "${concatStringsSep "," (map normalizeTag config.tailscaleAuth.allowedTags)}";''}
          '';
          # Server level, so every location (including regex ones) is covered.
          # $tailscale_auth_tags holds the caller's comma-separated tags.
          extraConfig = ''
            auth_request ${authPath};
            auth_request_set $tailscale_auth_tags $upstream_http_tailscale_tags;
          '';
        })
      ];
    }));
  };

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = cfg.enable || !builtins.any (vhost: vhost.tailscaleAuth.enable) (lib.attrValues config.services.nginx.virtualHosts);
        message = "services.nginx.tailscaleAuth.enable must be true when any nginx virtual host sets tailscaleAuth.enable.";
      }];
    }
    (mkIf cfg.enable {
      services.tailscaleAuth.enable = true;
      services.nginx.enable = true;

      services.nginx.virtualHosts = genAttrs cfg.virtualHosts (_: {
        tailscaleAuth.enable = true;
      });

      users.users.${config.services.nginx.user}.extraGroups = [ cfgAuth.group ];

      systemd.services.tailscale-nginx-auth = {
        after = [ "nginx.service" ];
        wants = [ "nginx.service" ];
      };
    })
  ];
}
