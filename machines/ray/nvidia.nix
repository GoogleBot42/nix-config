# This module provides the proprietary NVIDIA X11 / OpenGL drivers.

{ config, lib, pkgs, ... }:

with lib;

let
  nvidia_x11 = let
    drivers = config.services.xserver.videoDrivers;
    isDeprecated = str: (hasPrefix "nvidia" str) && (str != "nvidia");
    hasDeprecated = drivers: any isDeprecated drivers;
  in if (hasDeprecated drivers) then
    throw ''
      Selecting an nvidia driver has been modified for NixOS 19.03. The version is now set using `hardware.nvidia.package`.
    ''
  else if (elem "nvidia" drivers) then cfg.package else null;

  enabled = nvidia_x11 != null;
  cfg = config.hardware.nvidia;

  pCfg = cfg.prime;
  syncCfg = pCfg.sync;
  offloadCfg = pCfg.offload;
  reverseSyncCfg = pCfg.reverse_sync;
  primeEnabled = syncCfg.enable || reverseSyncCfg.enable || offloadCfg.enable;
  nvidiaPersistencedEnabled =  cfg.nvidiaPersistenced;
  nvidiaSettings = cfg.nvidiaSettings;
in

{
  imports =
    [
      (mkRenamedOptionModule [ "hardware" "nvidia" "optimus_prime" "enable" ] [ "hardware" "nvidia" "prime" "sync" "enable" ])
      (mkRenamedOptionModule [ "hardware" "nvidia" "optimus_prime" "allowExternalGpu" ] [ "hardware" "nvidia" "prime" "allowExternalGpu" ])
      (mkRenamedOptionModule [ "hardware" "nvidia" "prime" "sync" "allowExternalGpu" ] [ "hardware" "nvidia" "prime" "allowExternalGpu" ])
      (mkRenamedOptionModule [ "hardware" "nvidia" "optimus_prime" "nvidiaBusId" ] [ "hardware" "nvidia" "prime" "nvidiaBusId" ])
      (mkRenamedOptionModule [ "hardware" "nvidia" "optimus_prime" "intelBusId" ] [ "hardware" "nvidia" "prime" "intelBusId" ])
    ];

  options = {
    hardware.nvidia.powerManagement.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Experimental power management through systemd. For more information, see
        the NVIDIA docs, on Chapter 21. Configuring Power Management Support.
      '';
    };

    hardware.nvidia.powerManagement.finegrained = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Experimental power management of PRIME offload. For more information, see
        the NVIDIA docs, chapter 22. PCI-Express runtime power management.
      '';
    };

    hardware.nvidia.powerManagement.coarsegrained = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Experimental power management of PRIME offload. For more information, see
        the NVIDIA docs, chapter 22. PCI-Express runtime power management.
      '';
    };

    hardware.nvidia.modesetting.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable kernel modesetting when using the NVIDIA proprietary driver.

        Enabling this fixes screen tearing when using Optimus via PRIME (see
        <option>hardware.nvidia.prime.sync.enable</option>. This is not enabled
        by default because it is not officially supported by NVIDIA and would not
        work with SLI.
      '';
    };

    hardware.nvidia.prime.nvidiaBusId = mkOption {
      type = types.str;
      default = "";
      example = "PCI:1:0:0";
      description = ''
        Bus ID of the NVIDIA GPU. You can find it using lspci; for example if lspci
        shows the NVIDIA GPU at "01:00.0", set this option to "PCI:1:0:0".
      '';
    };

    hardware.nvidia.prime.intelBusId = mkOption {
      type = types.str;
      default = "";
      example = "PCI:0:2:0";
      description = ''
        Bus ID of the Intel GPU. You can find it using lspci; for example if lspci
        shows the Intel GPU at "00:02.0", set this option to "PCI:0:2:0".
      '';
    };

    hardware.nvidia.prime.amdgpuBusId = mkOption {
      type = types.str;
      default = "";
      example = "PCI:4:0:0";
      description = ''
        Bus ID of the AMD APU. You can find it using lspci; for example if lspci
        shows the AMD APU at "04:00.0", set this option to "PCI:4:0:0".
      '';
    };

    hardware.nvidia.prime.sync.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable NVIDIA Optimus support using the NVIDIA proprietary driver via PRIME.
        If enabled, the NVIDIA GPU will be always on and used for all rendering,
        while enabling output to displays attached only to the integrated Intel/AMD
        GPU without a multiplexer.

        Note that this option only has any effect if the "nvidia" driver is specified
        in <option>services.xserver.videoDrivers</option>, and it should preferably
        be the only driver there.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified (<option>hardware.nvidia.prime.nvidiaBusId</option> and
        <option>hardware.nvidia.prime.intelBusId</option> or 
        <option>hardware.nvidia.prime.amdgpuBusId</option>).

        If you enable this, you may want to also enable kernel modesetting for the
        NVIDIA driver (<option>hardware.nvidia.modesetting.enable</option>) in order
        to prevent tearing.

        Note that this configuration will only be successful when a display manager
        for which the <option>services.xserver.displayManager.setupCommands</option>
        option is supported is used.
      '';
    };

    hardware.nvidia.prime.allowExternalGpu = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Configure X to allow external NVIDIA GPUs when using Prime [Reverse] Sync.
      '';
    };

    hardware.nvidia.prime.offload.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable render offload support using the NVIDIA proprietary driver via PRIME.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified (<option>hardware.nvidia.prime.nvidiaBusId</option> and
        <option>hardware.nvidia.prime.intelBusId</option> or 
        <option>hardware.nvidia.prime.amdgpuBusId</option>).
      '';
    };

    hardware.nvidia.prime.offload.enableOffloadCmd = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Adds a `nvidia-offload` convenience script to <option>environment.systemPackages</option>
        for offloading programs to an nvidia device. To work, should have also enabled
        <option>hardware.nvidia.prime.offload.enable</option> or <option>hardware.nvidia.prime.reverse_sync.enable</option>

        Example usage `nvidia-offload sauerbraten_client`
      '';
    };

    hardware.nvidia.prime.reverse_sync.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Warning: This feature is relatively new, depending on your system this might
        work poorly. AMD support, especially so.
        See: https://forums.developer.nvidia.com/t/the-all-new-outputsink-feature-aka-reverse-prime/129828

        Enable NVIDIA Optimus support using the NVIDIA proprietary driver via reverse
        PRIME. If enabled, the Intel/AMD GPU will be used for all rendering, while
        enabling output to displays attached only to the NVIDIA GPU without a
        multiplexer.

        Note that this option only has any effect if the "nvidia" driver is specified
        in <option>services.xserver.videoDrivers</option>, and it should preferably
        be the only driver there.

        If this is enabled, then the bus IDs of the NVIDIA and Intel/AMD GPUs have to
        be specified (<option>hardware.nvidia.prime.nvidiaBusId</option> and
        <option>hardware.nvidia.prime.intelBusId</option> or 
        <option>hardware.nvidia.prime.amdgpuBusId</option>).

        If you enable this, you may want to also enable kernel modesetting for the
        NVIDIA driver (<option>hardware.nvidia.modesetting.enable</option>) in order
        to prevent tearing.

        Note that this configuration will only be successful when a display manager
        for which the <option>services.xserver.displayManager.setupCommands</option>
        option is supported is used.
      '';
    };

    hardware.nvidia.nvidiaSettings = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to add nvidia-settings, NVIDIA's GUI configuration tool, to
        systemPackages.
      '';
    };

    hardware.nvidia.nvidiaPersistenced = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Update for NVIDA GPU headless mode, i.e. nvidia-persistenced. It ensures all
        GPUs stay awake even during headless mode.
      '';
    };

    hardware.nvidia.package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = literalExpression "config.boot.kernelPackages.nvidiaPackages.stable";
      description = ''
        The NVIDIA X11 derivation to use.
      '';
      example = literalExpression "config.boot.kernelPackages.nvidiaPackages.legacy_340";
    };
  };

  config = let
      igpuDriver = if pCfg.intelBusId != "" then "modesetting" else "amdgpu";
      igpuBusId = if pCfg.intelBusId != "" then pCfg.intelBusId else pCfg.amdgpuBusId;
  in mkIf enabled {
    assertions = [
      {
        assertion = primeEnabled -> pCfg.intelBusId == "" || pCfg.amdgpuBusId == "";
        message = ''
          You cannot configure both an Intel iGPU and an AMD APU. Pick the one corresponding to your processor.
        '';
      }

      {
        assertion = offloadCfg.enableOffloadCmd -> offloadCfg.enable || reverseSyncCfg.enable;
        message = ''
          Offload command requires offloading or reverse prime sync to be enabled.
        '';
      }

      {
        assertion = primeEnabled -> pCfg.nvidiaBusId != "" && (pCfg.intelBusId != "" || pCfg.amdgpuBusId != "");
        message = ''
          When NVIDIA PRIME is enabled, the GPU bus IDs must configured.
        '';
      }

      {
        assertion = offloadCfg.enable -> versionAtLeast nvidia_x11.version "435.21";
        message = "NVIDIA PRIME render offload is currently only supported on versions >= 435.21.";
      }

      {
        assertion = (reverseSyncCfg.enable && pCfg.amdgpuBusId != "") -> versionAtLeast nvidia_x11.version "470.0";
        message = "NVIDIA PRIME render offload for AMD APUs is currently only supported on versions >= 470 beta.";
      }

      {
        assertion = !(syncCfg.enable && offloadCfg.enable);
        message = "PRIME Sync and Offload cannot be both enabled";
      }

      {
        assertion = !(syncCfg.enable && reverseSyncCfg.enable);
        message = "PRIME Sync and PRIME Reverse Sync cannot be both enabled";
      }

      {
        assertion = !(syncCfg.enable && cfg.powerManagement.finegrained && cfg.powerManagement.coarsegrained);
        message = "Sync precludes powering down the NVIDIA GPU.";
      }

      {
        assertion = cfg.powerManagement.finegrained -> offloadCfg.enable;
        message = "Fine-grained power management requires offload to be enabled.";
      }

      {
        assertion = cfg.powerManagement.coarsegrained -> offloadCfg.enable;
        message = "Coarse-grained power management requires offload to be enabled.";
      }

      {
        assertion = cfg.powerManagement.enable -> (
          builtins.pathExists (cfg.package.out + "/bin/nvidia-sleep.sh") &&
          builtins.pathExists (cfg.package.out + "/lib/systemd/system-sleep/nvidia")
        );
        message = "Required files for driver based power management don't exist.";
      }
    ];

    # If Optimus/PRIME is enabled, we:
    # - Specify the configured NVIDIA GPU bus ID in the Device section for the
    #   "nvidia" driver.
    # - Add the AllowEmptyInitialConfiguration option to the Screen section for the
    #   "nvidia" driver, in order to allow the X server to start without any outputs.
    # - Add a separate Device section for the Intel GPU, using the "modesetting"
    #   driver and with the configured BusID.
    # - OR add a separate Device section for the AMD APU, using the "amdgpu"
    #   driver and with the configures BusID.
    # - Reference that Device section from the ServerLayout section as an inactive
    #   device.
    # - Configure the display manager to run specific `xrandr` commands which will
    #   configure/enable displays connected to the Intel iGPU / AMD APU.

    services.xserver.useGlamor = mkDefault offloadCfg.enable;

    # reverse sync implies offloading
    hardware.nvidia.prime.offload.enable = mkDefault reverseSyncCfg.enable;

    services.xserver.drivers = optional primeEnabled {
      name = igpuDriver;
      display = !syncCfg.enable;
      modules = optional (igpuDriver == "amdgpu") [ pkgs.xorg.xf86videoamdgpu ];
      deviceSection = ''
        BusID "${igpuBusId}"
        ${optionalString (syncCfg.enable && igpuDriver != "amdgpu") ''Option "AccelMethod" "none"''}
      '';
    } ++ singleton {
      name = "nvidia";
      modules = [ nvidia_x11.bin ];
      display = syncCfg.enable;
      deviceSection = optionalString primeEnabled ''
        BusID "${pCfg.nvidiaBusId}"
        ${optionalString pCfg.allowExternalGpu "Option \"AllowExternalGpus\""}
      '';
    };

    services.xserver.serverLayoutSection = optionalString syncCfg.enable ''
      Inactive "Device-${igpuDriver}[0]"
    '' + optionalString reverseSyncCfg.enable ''
      Inactive "Device-nvidia[0]"
    '' + optionalString offloadCfg.enable ''
      Option "AllowNVIDIAGPUScreens"
    '';

    services.xserver.displayManager.setupCommands = let
      gpuProviderName = if igpuDriver == "amdgpu" then
        # find the name of the provider if amdgpu
        "`${pkgs.xorg.xrandr}/bin/xrandr --listproviders | ${pkgs.gnugrep}/bin/grep -i AMD | ${pkgs.gnused}/bin/sed -n 's/^.*name://p'`"
      else
        igpuDriver;
      providerCmdParams = if syncCfg.enable then "\"${gpuProviderName}\" NVIDIA-0" else "NVIDIA-G0 \"${gpuProviderName}\"";
    in optionalString (syncCfg.enable || reverseSyncCfg.enable) ''
      # Added by nvidia configuration module for Optimus/PRIME.
      ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource ${providerCmdParams}
      ${pkgs.xorg.xrandr}/bin/xrandr --auto
    '';

    environment.etc."nvidia/nvidia-application-profiles-rc" = mkIf nvidia_x11.useProfiles {
      source = "${nvidia_x11.bin}/share/nvidia/nvidia-application-profiles-rc";
    };

    # 'nvidia_x11' installs it's files to /run/opengl-driver/...
    environment.etc."egl/egl_external_platform.d".source =
      "/run/opengl-driver/share/egl/egl_external_platform.d/";

    hardware.opengl.extraPackages = [
      nvidia_x11.out
      # pkgs.nvidia-vaapi-driver
    ];
    hardware.opengl.extraPackages32 = [
      nvidia_x11.lib32
      # pkgs.pkgsi686Linux.nvidia-vaapi-driver
    ];

    environment.systemPackages = [ nvidia_x11.bin ]
      ++ optionals cfg.nvidiaSettings [ nvidia_x11.settings ]
      ++ optionals nvidiaPersistencedEnabled [ nvidia_x11.persistenced ]
      ++ optionals offloadCfg.enableOffloadCmd [ 
        (pkgs.writeShellScriptBin "nvidia-offload" ''
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export __VK_LAYER_NV_optimus=NVIDIA_only
          exec -a "$0" "$@"
        '') 
      ];

    systemd.packages = optional cfg.powerManagement.enable nvidia_x11.out;

    systemd.services = let
      baseNvidiaService = state: {
        description = "NVIDIA system ${state} actions";

        path = with pkgs; [ kbd ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${nvidia_x11.out}/bin/nvidia-sleep.sh '${state}'";
        };
      };

      nvidiaService = sleepState: (baseNvidiaService sleepState) // {
        before = [ "systemd-${sleepState}.service" ];
        requiredBy = [ "systemd-${sleepState}.service" ];
      };

      services = (builtins.listToAttrs (map (t: nameValuePair "nvidia-${t}" (nvidiaService t)) ["hibernate" "suspend"]))
        // {
          nvidia-resume = (baseNvidiaService "resume") // {
            after = [ "systemd-suspend.service" "systemd-hibernate.service" ];
            requiredBy = [ "systemd-suspend.service" "systemd-hibernate.service" ];
          };
        };
    in optionalAttrs cfg.powerManagement.enable services
      // optionalAttrs nvidiaPersistencedEnabled {
        "nvidia-persistenced" = mkIf nvidiaPersistencedEnabled {
          description = "NVIDIA Persistence Daemon";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "forking";
            Restart = "always";
            PIDFile = "/var/run/nvidia-persistenced/nvidia-persistenced.pid";
            ExecStart = "${nvidia_x11.persistenced}/bin/nvidia-persistenced --verbose";
            ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-persistenced";
          };
        };
      };

    systemd.tmpfiles.rules = optional config.virtualisation.docker.enableNvidia
        "L+ /run/nvidia-docker/bin - - - - ${nvidia_x11.bin}/origBin"
      ++ optional (nvidia_x11.persistenced != null && config.virtualisation.docker.enableNvidia)
        "L+ /run/nvidia-docker/extras/bin/nvidia-persistenced - - - - ${nvidia_x11.persistenced}/origBin/nvidia-persistenced";

    boot.extraModulePackages = [ nvidia_x11.bin ];

    # nvidia-uvm is required by CUDA applications.
    boot.kernelModules = [ "nvidia-uvm" ] ++
      optionals config.services.xserver.enable [ "nvidia" "nvidia_modeset" "nvidia_drm" ];

    # If requested enable modesetting via kernel parameter.
    boot.kernelParams = optional (offloadCfg.enable || cfg.modesetting.enable) "nvidia-drm.modeset=1"
      ++ optional cfg.powerManagement.enable "nvidia.NVreg_PreserveVideoMemoryAllocations=1";

    services.udev.extraRules =
      ''
        # Create /dev/nvidia-uvm when the nvidia-uvm module is loaded.
        KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 255'"
        KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 254'"
        KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia%n c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) %n'"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
      '' + optionalString (cfg.powerManagement.finegrained || cfg.powerManagement.coarsegrained) ''
        # Remove NVIDIA USB xHCI Host Controller devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

        # Remove NVIDIA USB Type-C UCSI devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

        # Remove NVIDIA Audio devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"

        # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
        ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

        # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
      '';

    boot.extraModprobeConfig = optionalString cfg.powerManagement.finegrained ''
      options nvidia "NVreg_DynamicPowerManagement=0x02"
    '' + optionalString cfg.powerManagement.coarsegrained ''
      options nvidia "NVreg_DynamicPowerManagement=0x01"
    '';

    boot.blacklistedKernelModules = [ "nouveau" "nvidiafb" ];

    services.acpid.enable = true;

  };

}
