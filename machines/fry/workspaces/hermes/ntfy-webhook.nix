{ lib, pkgs, ... }:

let
  hermesUser = "googlebot";
  hermesGroup = "users";
  hermesStateDir = "/var/lib/hermes";
  ntfyTopic = "service-failures";
  ntfySubscription = "ntfy-service-failures";
  ntfySecretFile = "${hermesStateDir}/.hermes/${ntfySubscription}.secret";
  ntfyPrompt = ''
    ntfy alert from topic {topic}
    Title: {title}
    Priority: {priority}
    Tags: {tags}
    Attachment metadata:
    {attachment}
    Message:
    {message}

    If attachment metadata includes a URL or other useful context, use it during the investigation.
    Investigate the reported problem and make a fix when appropriate. If the alert is not actionable, explain why.
  '';

  mkService = extra: {
    User = hermesUser;
    Group = hermesGroup;
    Restart = "always";
    RestartSec = "5";
  } // extra;

  ntfyWebhookBootstrap = pkgs.writeShellScript "ntfy-webhook-bootstrap" ''
    set -euo pipefail
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.openssl ]}"
    export HERMES_HOME=${lib.escapeShellArg "${hermesStateDir}/.hermes"}

    install -d -m 0700 -o ${hermesUser} -g ${hermesGroup} "$HERMES_HOME"

    if [ ! -s ${lib.escapeShellArg ntfySecretFile} ]; then
      umask 077
      openssl rand -hex 32 > ${lib.escapeShellArg ntfySecretFile}
      chown ${hermesUser}:${hermesGroup} ${lib.escapeShellArg ntfySecretFile}
      chmod 0600 ${lib.escapeShellArg ntfySecretFile}
    fi

    /run/current-system/sw/bin/hermes webhook remove ${lib.escapeShellArg ntfySubscription} >/dev/null 2>&1 || true
    /run/current-system/sw/bin/hermes webhook subscribe ${lib.escapeShellArg ntfySubscription} \
      --description ${lib.escapeShellArg "Receive-only ntfy alerts relayed into Hermes from ${ntfyTopic}"} \
      --prompt ${lib.escapeShellArg ntfyPrompt} \
      --secret "$(tr -d '\n' < ${lib.escapeShellArg ntfySecretFile})"
  '';

  ntfyWebhookForwarder = pkgs.writeShellScript "ntfy-webhook-forwarder" ''
    set -euo pipefail
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.curl pkgs.openssl pkgs.gawk ]}"

    body="''${NTFY_RAW:-}"
    [ -n "$body" ] || exit 0

    secret="$(tr -d '\n' < ${lib.escapeShellArg ntfySecretFile})"
    signature="$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$secret" -hex | awk '{ print $NF }')"

    curl \
      --fail --silent --show-error \
      --max-time 30 --retry 3 \
      -H 'Content-Type: application/json' \
      -H "X-Hub-Signature-256: sha256=$signature" \
      --data-binary "$body" \
      http://127.0.0.1:8644/webhooks/${ntfySubscription}
  '';

  ntfyWebhookRelay = pkgs.writeShellScript "ntfy-webhook-relay" ''
    set -euo pipefail
    PATH="${lib.makeBinPath [ pkgs.ntfy-sh ]}"
    exec ntfy subscribe --token "$NTFY_TOKEN" ${lib.escapeShellArg "ntfy.neet.dev/${ntfyTopic}"} ${lib.escapeShellArg ntfyWebhookForwarder}
  '';
in
{
  systemd.services.ntfy-webhook-bootstrap = {
    description = "Bootstrap Hermes webhook route for relayed ntfy alerts";
    wantedBy = [ "multi-user.target" ];
    before = [ "hermes-agent.service" "ntfy-to-hermes-relay.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = hermesUser;
      Group = hermesGroup;
      Environment = [ "HERMES_HOME=${hermesStateDir}/.hermes" ];
      ExecStart = ntfyWebhookBootstrap;
    };
  };

  systemd.services.ntfy-to-hermes-relay = {
    description = "Subscribe to ntfy alerts and relay them into Hermes webhooks";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "hermes-agent.service" "ntfy-webhook-bootstrap.service" ];
    wants = [ "network-online.target" "hermes-agent.service" "ntfy-webhook-bootstrap.service" ];
    requires = [ "ntfy-webhook-bootstrap.service" ];
    serviceConfig = mkService {
      Type = "simple";
      EnvironmentFile = "/etc/ntfy-token";
      ExecStartPre = "${pkgs.curl}/bin/curl --fail --silent --show-error http://127.0.0.1:8644/health";
      ExecStart = ntfyWebhookRelay;
    };
  };
}
