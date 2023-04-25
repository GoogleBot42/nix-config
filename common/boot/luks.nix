# Makes it a little easier to configure luks partitions for boot
# Additionally, this solves a circular dependency between kexec luks
# and NixOS's luks module.

{ config, lib, ... }:

let
  cfg = config.luks;

  deviceCount = builtins.length cfg.devices;

  deviceMap = lib.imap
    (i: item: {
      device = item;
      name =
        if deviceCount == 1 then "enc-pv"
        else "enc-pv${builtins.toString (i + 1)}";
    })
    cfg.devices;
in
{
  options.luks = {
    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    allowDiscards = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    fallbackToPassword = lib.mkEnableOption
      "Fallback to interactive passphrase prompt if the cannot be found.";

    disableKeyring = lib.mkEnableOption
      "When opening LUKS2 devices, don't use the kernel keyring";

    # set automatically, don't touch
    deviceNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = deviceCount == builtins.length (builtins.attrNames config.boot.initrd.luks.devices);
          message = ''
            All luks devices must be specified using `luks.devices` not `boot.initrd.luks.devices`.
          '';
        }
      ];
    }
    (lib.mkIf (deviceCount != 0) {
      luks.deviceNames = builtins.map (device: device.name) deviceMap;

      boot.initrd.luks.devices = lib.listToAttrs (
        builtins.map
          (item:
            {
              name = item.name;
              value = {
                device = item.device;
                allowDiscards = cfg.allowDiscards;
                fallbackToPassword = cfg.fallbackToPassword;
                disableKeyring = cfg.disableKeyring;
              };
            })
          deviceMap);
    })
  ];
}
