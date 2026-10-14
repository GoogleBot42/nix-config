{ config, lib, pkgs, ... }:

# The one way this module talks to ntfy. A message that cannot be delivered
# (uplink or Tailscale not up yet, server down) is spooled on disk and sent
# by the flush timer once delivery works again, so a problem found in the
# first minute after boot still reaches the owner instead of being lost.

let
  cfg = config.ntfy-alerts;
  spoolDir = "/var/lib/ntfy-spool";

  # ntfy-notify TOPIC PRIORITY TAGS TITLE BODY [ATTACHMENT-FILE ATTACHMENT-NAME]
  # NTFY_TOKEN comes from the environment or /run/agenix/ntfy-token.
  # NTFY_DRY_RUN=1 prints instead of sending.
  notify = pkgs.writeShellScript "ntfy-notify" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.curl ]}"
    topic=$1 priority=$2 tags=$3 title=$4 body=$5 attach=''${6:-} attachName=''${7:-}
    if [ -n "''${NTFY_DRY_RUN:-}" ]; then
      printf 'ntfy dry run: [%s/%s/%s] %s: %s%s\n' "$topic" "$priority" "$tags" "$title" "$body" "''${attach:+ (+$attachName)}"
      exit 0
    fi
    if [ -z "''${NTFY_TOKEN:-}" ] && [ -r /run/agenix/ntfy-token ]; then
      # shellcheck disable=SC1091
      . /run/agenix/ntfy-token
    fi
    send() {
      if [ -n "$attach" ]; then
        curl --fail --silent --show-error --max-time 30 --retry 2 --retry-connrefused \
          ${cfg.curlExtraArgs} \
          -H "Authorization: Bearer $NTFY_TOKEN" -H "Title: $title" -H "Priority: $priority" \
          -H "Tags: $tags" -H "Message: $body" -H "Filename: $attachName" -T "$attach" \
          "${cfg.serverUrl}/$topic" > /dev/null
      else
        curl --fail --silent --show-error --max-time 30 --retry 2 --retry-connrefused \
          ${cfg.curlExtraArgs} \
          -H "Authorization: Bearer $NTFY_TOKEN" -H "Title: $title" -H "Priority: $priority" \
          -H "Tags: $tags" -d "$body" \
          "${cfg.serverUrl}/$topic" > /dev/null
      fi
    }
    if send; then exit 0; fi
    # Could not deliver: spool for the flush timer. One directory per message.
    dir="${spoolDir}/$(date +%s)-$$-$RANDOM"
    mkdir -p "$dir"
    printf '%s\n' "$topic" "$priority" "$tags" "$title" > "$dir/meta"
    printf '%s' "$body" > "$dir/body"
    if [ -n "$attach" ]; then cp "$attach" "$dir/attach"; printf '%s' "$attachName" > "$dir/attach.name"; fi
    echo "ntfy-notify: delivery failed, spooled as $dir" >&2
    exit 0
  '';

  flush = pkgs.writeShellScript "ntfy-spool-flush" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.curl pkgs.findutils ]}"
    [ -d ${spoolDir} ] || exit 0
    # Give up on anything older than a week.
    find ${spoolDir} -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -r {} +
    for dir in $(ls -d ${spoolDir}/*/ 2>/dev/null | sort); do
      { read -r topic; read -r priority; read -r tags; read -r title; } < "$dir/meta"
      body=$(cat "$dir/body")
      if [ -f "$dir/attach" ]; then
        curl --fail --silent --show-error --max-time 30 --retry 2 --retry-connrefused \
          ${cfg.curlExtraArgs} \
          -H "Authorization: Bearer $NTFY_TOKEN" -H "Title: $title (delayed)" -H "Priority: $priority" \
          -H "Tags: $tags" -H "Message: $body" -H "Filename: $(cat "$dir/attach.name")" -T "$dir/attach" \
          "${cfg.serverUrl}/$topic" > /dev/null || exit 0
      else
        curl --fail --silent --show-error --max-time 30 --retry 2 --retry-connrefused \
          ${cfg.curlExtraArgs} \
          -H "Authorization: Bearer $NTFY_TOKEN" -H "Title: $title (delayed)" -H "Priority: $priority" \
          -H "Tags: $tags" -d "$body" \
          "${cfg.serverUrl}/$topic" > /dev/null || exit 0
      fi
      rm -r "$dir"
      echo "flushed spooled notification: $title"
    done
  '';
in
{
  options.ntfy-alerts.notify = lib.mkOption {
    type = lib.types.path;
    default = notify;
    readOnly = true;
    description = ''
      Script every alert sender uses:
      `ntfy-notify TOPIC PRIORITY TAGS TITLE BODY [ATTACHMENT-FILE ATTACHMENT-NAME]`.
      Spools on delivery failure; see ntfy-spool-flush.
    '';
  };

  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    systemd.tmpfiles.rules = [ "d ${spoolDir} 0700 root root -" ];

    systemd.services.ntfy-spool-flush = {
      description = "Deliver spooled ntfy notifications";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        ExecStart = flush;
      };
    };
    systemd.timers.ntfy-spool-flush = {
      description = "Retry spooled ntfy notifications";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "2min";
      };
    };
  };
}
