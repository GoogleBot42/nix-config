{ pkgs, ... }:

# Test container workspace configuration
#
# Add to sandboxed-workspace.workspaces in machines/fry/default.nix:
#   sandboxed-workspace.workspaces.test-container = {
#     type = "container" OR "incus";
#     config = ./workspaces/test-container.nix;
#     ip = "192.168.83.50";
#   };
#
# The workspace name ("test-container") becomes the hostname automatically.
# The IP is configured in default.nix, not here.
#
# This container is the kiln development box: the GPU and Jeremy's phone
# (USB passthrough) live here, so the nightly benchmark runs here too, as a
# systemd timer. It borrows the phone and the GPU under the same file locks
# the interactive agent sessions use (kiln: tools/nightly.sh), so it never
# owns the hardware; when a session holds a lock the lane is recorded as
# unavailable rather than measured.

let
  kilnUser = "googlebot";
  kilnHome = "/home/${kilnUser}";
  # A dedicated checkout, pulled to origin/master before every run, so the
  # nightly never measures or disturbs an agent's working tree.
  kilnNightlyCheckout = "${kilnHome}/workspace/kiln-nightly";
in
{
  environment.systemPackages = with pkgs; [
    # Add packages here
  ];

  # Google devices (vendor 18d1) readable by the benchmark and the agents
  # without a doas chmod after every replug. If udev does not act on
  # passthrough nodes inside the container, the same rule belongs on the
  # host.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"
  '';

  systemd.services.kiln-nightly-bench = {
    description = "kiln nightly benchmark (desktop GPU lane and phone lane, pushed to the metrics store)";
    path = with pkgs; [ nix git bash coreutils util-linux gnugrep gawk openssh ];
    environment = {
      HOME = kilnHome;
      KILN_NIGHTLY_CHECKOUT = kilnNightlyCheckout;
      # The adb server every process in this container shares; a second
      # server on another port would steal the single USB claim.
      ANDROID_ADB_SERVER_PORT = "5050";
      ANDROID_SERIAL = "61241FDCG0013M";
    };
    serviceConfig = {
      Type = "oneshot";
      User = kilnUser;
      Group = "users";
      WorkingDirectory = kilnHome;
      # Where the rows go lands here once the dashboard exists
      # (KILN_METRICS_URL and its token); absent, the run spools rows locally.
      EnvironmentFile = [ "-${kilnHome}/.config/kiln/metrics.env" ];
      # Bounded: a batch is about twenty minutes; the locks wait a few more.
      TimeoutStartSec = "90min";
      Nice = 5;
    };
    script = ''
      set -euo pipefail
      if [ ! -d "$KILN_NIGHTLY_CHECKOUT/.git" ]; then
        git clone -q gitea@git.neet.dev:zuckerberg/kiln.git "$KILN_NIGHTLY_CHECKOUT"
      fi
      cd "$KILN_NIGHTLY_CHECKOUT"
      git fetch -q origin && git checkout -q master && git reset -q --hard origin/master
      exec nix develop -c tools/nightly.sh
    '';
  };

  systemd.timers.kiln-nightly-bench = {
    description = "Run the kiln nightly benchmark at 04:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      # If the container was down at 04:00, run at the next boot instead.
      Persistent = true;
      RandomizedDelaySec = "10min";
      Unit = "kiln-nightly-bench.service";
    };
  };
}
