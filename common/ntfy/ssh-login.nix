{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;

  notifyScript = pkgs.writeShellScript "ssh-login-notify" ''
    # Only notify on session open, not close
    [ "$PAM_TYPE" = "open_session" ] || exit 0

    . /run/agenix/ntfy-token

    # Send notification in background so login isn't delayed
    ${lib.getExe pkgs.curl} \
      --fail --silent --show-error \
      --max-time 10 --retry 1 \
      ${cfg.curlExtraArgs} \
      -H "Authorization: Bearer $NTFY_TOKEN" \
      -H "Title: SSH login on ${config.networking.hostName}" \
      -H "Tags: key" \
      -d "$PAM_USER from $PAM_RHOST at $(date +%c)" \
      "${cfg.serverUrl}/ssh-logins" &
  '';
in
{
  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    security.pam.services.sshd.rules.session.ntfy-login = {
      order = 99999;
      control = "optional";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [
        "quiet"
        (toString notifyScript)
      ];
    };
  };
}
