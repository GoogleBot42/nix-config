{ config, pkgs, lib, ... }:

{
   disabledModules = [
    "hardware/video/nvidia.nix"
   ];
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
  ];

  firmware.x86_64.enable = true;
  efi.enable = true;

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/c1822e5f-4137-44e1-885f-954e926583ce";
    allowDiscards = true;
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "ray";

  hardware.enableAllFirmware = true;

  # depthai
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"
  '';

  # newer kernel for wifi
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # gpu
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.logFile = "/var/log/Xorg.0.log";
  hardware.nvidia = {
    modesetting.enable = true; # for nvidia-vaapi-driver
    prime = {
      sync.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:4:0:0";
    };
#    powerManagement = {
#      enable = true;
#      finegrained = true;
#      coarsegrained = true;
#    };
  };

  # virt-manager
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  environment.systemPackages = with pkgs; [ virt-manager ];
  users.users.googlebot.extraGroups = [ "libvirtd" ];

  # vpn-container.enable = true;
  # containers.vpn.interfaces = [ "piaw" ];

  # allow traffic for wireguard interface to pass
  # networking.firewall = {
  #   # wireguard trips rpfilter up
  #   extraCommands = ''
  #     ip46tables -t raw -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
  #     ip46tables -t raw -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
  #   '';
  #   extraStopCommands = ''
  #     ip46tables -t raw -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
  #     ip46tables -t raw -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
  #   '';
  # };

  # systemd.services.pia-vpn-wireguard = {
  #   enable = true;
  #   description = "PIA VPN WireGuard Tunnel";
  #   requires = [ "network-online.target" ];
  #   after = [ "network.target" "network-online.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   environment.DEVICE = "piaw";
  #   path = with pkgs; [ kmod wireguard-tools jq curl ];

  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };

  #   script = ''
  #     WG_HOSTNAME=zurich406
  #     WG_SERVER_IP=156.146.62.153

  #     PIA_USER=`sed '1q;d' /run/agenix/pia-login.conf`
  #     PIA_PASS=`sed '2q;d' /run/agenix/pia-login.conf`
  #     PIA_TOKEN=`curl -s -u "$PIA_USER:$PIA_PASS" https://www.privateinternetaccess.com/gtoken/generateToken | jq -r '.token'`
  #     privKey=$(wg genkey)
  #     pubKey=$(echo "$privKey" | wg pubkey)
  #     wireguard_json=`curl -s -G --connect-to "$WG_HOSTNAME::$WG_SERVER_IP:" --cacert "${./ca.rsa.4096.crt}" --data-urlencode "pt=$PIA_TOKEN" --data-urlencode "pubkey=$pubKey" https://$WG_HOSTNAME:1337/addKey`

  #     echo "               
  #     [Interface]
  #     Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
  #     PrivateKey = $privKey
  #     ListenPort = 51820
  #     [Peer]
  #     PersistentKeepalive = 25
  #     PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
  #     AllowedIPs = 0.0.0.0/0
  #     Endpoint = $WG_SERVER_IP:$(echo "$wireguard_json" | jq -r '.server_port')
  #     " > /tmp/piaw.conf

  #     # TODO make /tmp/piaw.conf ro to root

  #     ${lib.optionalString (!config.boot.isContainer) "modprobe wireguard"}
  #     wg-quick up /tmp/piaw.conf
  #   '';

  #   preStop = ''
  #     wg-quick down /tmp/piaw.conf
  #   '';
  # };
  # age.secrets."pia-login.conf".file = ../../secrets/pia-login.conf;

  virtualisation.docker.enable = true;

  services.zerotierone.enable = true;

  services.mount-samba.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}
