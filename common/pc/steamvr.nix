{ config, lib, pkgs, ... }:

# SteamVR runs inside Steam's bubblewrap sandbox, where setuid and file
# capabilities do not apply, so it can neither grant itself CAP_SYS_NICE nor
# raise its own priority. Both are done from outside the sandbox here, for
# every normal user's Steam library.
let
  cfg = config.de;
  users = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);
  launcherOf = u: "${u.home}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
  niceLevel = "-20";
  vrCfg = config.steamvr;
in
{
  options.steamvr.amdgpuHighPriority = lib.mkEnableOption (""
    + "a kernel patch letting any process create high-priority amdgpu contexts. "
    + "SteamVR's compositor needs one to preempt the game for on-time "
    + "reprojection, but Steam's sandbox strips the CAP_SYS_NICE the stock "
    + "kernel requires. Rebuilds the kernel locally");

  config = lib.mkIf cfg.enable {
    boot.kernelPatches = lib.mkIf vrCfg.amdgpuHighPriority [{
      name = "amdgpu-allow-high-priority";
      patch = ./amdgpu-allow-high-priority.patch;
    }];

    # SteamVR's setup script prompts for root on every start unless the
    # launcher already carries cap_sys_nice; SteamVR updates replace the file
    systemd.paths = lib.listToAttrs (map
      (u: lib.nameValuePair "steamvr-launcher-cap-${u.name}" {
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathChanged = launcherOf u;
      })
      users);

    systemd.services = lib.listToAttrs
      (map
        (u: lib.nameValuePair "steamvr-launcher-cap-${u.name}" {
          description = "Grant cap_sys_nice to ${u.name}'s SteamVR compositor launcher";
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.libcap pkgs.gnugrep ];
          serviceConfig.Type = "oneshot";
          script = ''
            [ -e ${launcherOf u} ] || exit 0
            getcap ${launcherOf u} | grep -q cap_sys_nice && exit 0
            setcap CAP_SYS_NICE=eip ${launcherOf u}
          '';
        })
        users) // {
      # Raise every thread of the compositor and of vrserver (which hosts the
      # vrlink video encoder) to the top CPU priority while SteamVR runs
      steamvr-priority = {
        description = "Raise SteamVR compositor and server thread priority";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.procps pkgs.util-linux ];
        serviceConfig.Restart = "always";
        script = ''
          while sleep 2; do
            for pid in $(pgrep -x 'vrcompositor|vrserver'); do
              ps -L -o tid=,nice= -p "$pid" | while read -r tid ni; do
                [ "$ni" = "${niceLevel}" ] || renice -n ${niceLevel} -p "$tid" >/dev/null 2>&1 || true
              done
            done
          done
        '';
      };
    };
  };
}
