{ lib, config, pkgs, ... }:

# power-profiles-daemon persists the last profile picked in the desktop
# across reboots, so a one-off "performance" choice would otherwise pin the
# CPU's energy-performance preference to performance indefinitely. Reset to
# balanced whenever the daemon starts; a session can still switch for as
# long as it runs.
{
  config = lib.mkIf config.services.power-profiles-daemon.enable {
    systemd.services.power-profiles-daemon.postStart = ''
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
    '';
  };
}
