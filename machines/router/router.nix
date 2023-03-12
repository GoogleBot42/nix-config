{ config, pkgs, lib, ... }:

let
  cfg = config.router;
  inherit (lib) mapAttrs' genAttrs nameValuePair mkOption types mkIf mkEnableOption;
in
{
  options.router = {
    enable = mkEnableOption "router";

    privateSubnet = mkOption {
      type = types.str;
      default = "192.168.1";
      description = "IP block (/24) to use for the private subnet";
    };
  };

  config = mkIf cfg.enable {
    networking.ip_forward = true;

    networking.interfaces.enp1s0.useDHCP = true;

    networking.nat = {
      enable = true;
      internalInterfaces = [
        "br0"
      ];
      externalInterface = "enp1s0";
    };

    networking.bridges = {
      br0 = {
        interfaces = [
          "enp2s0"
          "wlp4s0"
          "wlan1"
        ];
      };
    };

    networking.interfaces = {
      br0 = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "${cfg.privateSubnet}.1";
            prefixLength = 24;
          }
        ];
      };
    };

    networking.networkmanager.enable = false;

    services.dnsmasq = {
      enable = true;
      extraConfig = ''
        # sensible behaviours
        domain-needed
        bogus-priv
        no-resolv

        # upstream name servers
        server=1.1.1.1
        server=8.8.8.8

        # local domains
        expand-hosts
        domain=home
        local=/home/

        # Interfaces to use DNS on
        interface=br0

        # subnet IP blocks to use DHCP on
        dhcp-range=${cfg.privateSubnet}.10,${cfg.privateSubnet}.254,24h
      '';
    };

    networking.firewall.enable = lib.mkForce false; # TODO

    services.hostapd = {
      enable = true;
      radios = {
        # 2.4GHz
        wlp4s0 = {
          hwMode = "g";
          noScan = true;
          channel = 6;
          countryCode = "US";
          wifi4 = {
            capabilities = ["LDPC" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1" "MAX-AMSDU-7935" "HT40+"];
          };
          wifi5 = {
            operatingChannelWidth = "20or40";
            capabilities = ["MAX-A-MPDU-LEN-EXP0"];
          };
          wifi6 = {
            enable = true;
            singleUserBeamformer = true;
            singleUserBeamformee = true;
            multiUserBeamformer = true;
            operatingChannelWidth = "20or40";
          };
          networks.wlp4s0 = {
            ssid = "- Experimental 5G Tower by AT&T";
            authentication.saePasswordsFile = "/run/agenix/hostapd-pw-experimental-tower";
          };
          extraConfig = ''
            he_oper_centr_freq_seg0_idx=8
            vht_oper_centr_freq_seg0_idx=8
          '';
        };

        # 5GHz
        wlan1 = {
          hwMode = "a";
          noScan = true;
          channel = 128;
          countryCode = "US";
          wifi4 = {
            capabilities = ["LDPC" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1" "MAX-AMSDU-7935" "HT40-"];
          };
          wifi5 = {
            operatingChannelWidth = "160";
            capabilities = ["RXLDPC" "SHORT-GI-80" "SHORT-GI-160" "TX-STBC-2BY1" "SU-BEAMFORMER" "SU-BEAMFORMEE" "MU-BEAMFORMER" "MU-BEAMFORMEE" "RX-ANTENNA-PATTERN" "TX-ANTENNA-PATTERN" "RX-STBC-1" "SOUNDING-DIMENSION-3" "BF-ANTENNA-3" "VHT160" "MAX-MPDU-11454" "MAX-A-MPDU-LEN-EXP7"];
          };
          wifi6 = {
            enable = true;
            singleUserBeamformer = true;
            singleUserBeamformee = true;
            multiUserBeamformer = true;
            operatingChannelWidth = "160";
          };
          networks.wlan1 = {
            ssid = "- Experimental 5G Tower by AT&T";
            authentication.saePasswordsFile = "/run/agenix/hostapd-pw-experimental-tower";
          };
          extraConfig = ''
            vht_oper_centr_freq_seg0_idx=114
            he_oper_centr_freq_seg0_idx=114
          '';
        };
      };
    };
    age.secrets.hostapd-pw-experimental-tower.file = ../../secrets/hostapd-pw-experimental-tower.age;

    hardware.firmware = [
      pkgs.mt7916-firmware
    ];

    nixpkgs.overlays = [
      (self: super: {
        mt7916-firmware = pkgs.stdenvNoCC.mkDerivation {
          pname = "mt7916-firmware";
          version = "custom-feb-02-23";
          src = ./firmware/mediatek; # from here https://github.com/openwrt/mt76/issues/720#issuecomment-1413537674
          dontBuild = true;
          installPhase = ''
            for i in \
              mt7916_eeprom.bin \
              mt7916_rom_patch.bin \
              mt7916_wa.bin \
              mt7916_wm.bin;
            do
              install -D -pm644 $i $out/lib/firmware/mediatek/$i
            done
          '';
          meta = with lib; {
            license = licenses.unfreeRedistributableFirmware;
          };
        };
      })
    ];
  };
}