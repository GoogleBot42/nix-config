{ pkgs, ... }:

# SteamVR runs inside Steam's bubblewrap sandbox, where setuid and file
# capabilities do not apply, so it can neither grant itself CAP_SYS_NICE nor
# raise its own priority. Both are done from outside the sandbox here.
let
  user = "john";
  launcher = "/home/${user}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
  niceLevel = "-20";
in
{
  # SteamVR's setup script prompts for root on every start unless the launcher
  # already carries cap_sys_nice; SteamVR updates replace the file
  systemd.paths.steamvr-launcher-cap = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = launcher;
  };
  systemd.services.steamvr-launcher-cap = {
    description = "Grant cap_sys_nice to the SteamVR compositor launcher";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.libcap pkgs.gnugrep ];
    serviceConfig.Type = "oneshot";
    script = ''
      [ -e ${launcher} ] || exit 0
      getcap ${launcher} | grep -q cap_sys_nice && exit 0
      setcap CAP_SYS_NICE=eip ${launcher}
    '';
  };

  # Raise every thread of the compositor and of vrserver (which hosts the
  # vrlink video encoder) to the top CPU priority while SteamVR runs
  systemd.services.steamvr-priority = {
    description = "Raise SteamVR compositor and server thread priority";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.procps pkgs.util-linux ];
    serviceConfig.Restart = "always";
    script = ''
      while sleep 2; do
        for pid in $(pgrep -u ${user} -x 'vrcompositor|vrserver'); do
          ps -L -o tid=,nice= -p "$pid" | while read -r tid ni; do
            [ "$ni" = "${niceLevel}" ] || renice -n ${niceLevel} -p "$tid" >/dev/null 2>&1 || true
          done
        done
      done
    '';
  };
}
