{ pkgs, lib, ... }:

# Chassis fans on the Mono Gateway DK hang off a Microchip EMC2305 fan
# controller (i2c, behind the PCA9545 mux). Mainline exposes it only as a
# hwmon device with a cooling device that no thermal zone references, so
# nothing in the kernel drives it; left alone the fans sit wherever the
# chip's power-on default puts them (full speed). This loop steers them from
# the SoC's hottest thermal zone with Mono's own curve: off below 40 °C, a
# 51/255 kick at 40 °C, full speed at 80 °C.
let
  fanControl = pkgs.writeShellApplication {
    name = "leela-fan-control";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      min_temp=40
      max_temp=80
      min_start=51

      emc() {
        for n in /sys/class/hwmon/hwmon*/name; do
          if [ "$(cat "$n")" = emc2305 ]; then dirname "$n"; return; fi
        done
        return 1
      }

      set_pwm() {
        local dir=$1 value=$2
        for p in "$dir"/pwm[0-9]*; do
          [ -f "$p" ] && echo "$value" > "$p"
        done
      }

      while :; do
        if dir=$(emc); then
          temp=$(cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -n 1)
          temp=$((temp / 1000))
          if [ "$temp" -lt "$min_temp" ]; then
            pwm=0
          else
            pwm=$((min_start + (temp - min_temp) * (255 - min_start) / (max_temp - min_temp)))
            [ "$pwm" -gt 255 ] && pwm=255
          fi
          set_pwm "$dir" "$pwm"
        fi
        sleep 10
      done
    '';
  };

  fansFull = pkgs.writeShellScript "leela-fans-full" ''
    for p in /sys/class/hwmon/hwmon*/pwm[0-9]*; do
      n=$(dirname "$p")/name
      [ "$(cat "$n" 2>/dev/null)" = emc2305 ] && echo 255 > "$p"
    done
    exit 0
  '';
in
{
  systemd.services.leela-fan-control = {
    description = "Drive the EMC2305 chassis fans from the SoC thermal zones";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      ExecStart = lib.getExe fanControl;
      # Fail safe: whenever the loop is not running, the fans run flat out.
      ExecStopPost = fansFull;
      Restart = "always";
      RestartSec = 5;
    };
  };
}
