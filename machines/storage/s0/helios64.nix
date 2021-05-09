{ pkgs, lib, ... }:

{
  # Fan speed adjustment
  systemd.services.fans = {
    wantedBy = ["multi-user.target"];
    serviceConfig.ExecStart = pkgs.runCommandCC "fans" { nativeBuildInputs = [ pkgs.rustc ]; } ''
      rustc ${./fancontrol.rs} -o $out
    '';
    serviceConfig.Restart = "always";
  };

  boot = {
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./kernel.nix {});
    #kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = ["panic=3" "boot.shell_on_fail"];
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    initrd.postDeviceCommands = ''
      (
      cd /sys/bus/platform/drivers/sdhci-arasan
      while true; do
        test -e fe330000.sdhci/mmc_host/mmc*/mmc*/block && break
        echo fe330000.sdhci > unbind
        echo fe330000.sdhci > bind
        sleep 1
      done
      )
    '';
  };

  systemd.services.disable-offload = {
    wantedBy = ["sys-devices-platform-fe300000.ethernet-net-eth0.device" "multi-user.targtet"];
    after = ["sys-devices-platform-fe300000.ethernet-net-eth0.device"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.ethtool}/bin/ethtool --offload eth0 tx off";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
}
