{ pkgs, lib, config, ... }:

{
  nixpkgs.overlays = [
    (self: super:

    with self;

    let
      # arch = builtins.elemAt (lib.strings.splitString "-" builtins.currentSystem) 0;
      arch = "x86_64";

      pia-desktop = clangStdenv.mkDerivation rec {
        pname = "pia-desktop";
        version = "3.3.0";

        src = fetchgit {
          url = "https://github.com/pia-foss/desktop";
          rev = version;
          fetchLFS = true;
          sha256 = "D9txL5MUWyRYTnsnhlQdYT4dGVpj8PFsVa5hkrb36cw=";
        };

        patches = [
          ./fix-pia.patch
        ];

        nativeBuildInputs = [
          cmake
          rake
        ];

        prePatch = ''
          sed -i 's|/usr/include/libnl3|${libnl.dev}/include/libnl3|' Rakefile
        '';

        installPhase = ''
          mkdir -p $out/bin $out/lib $out/share
          cp -r ../out/pia_release_${arch}/stage/bin $out
          cp -r ../out/pia_release_${arch}/stage/lib $out
          cp -r ../out/pia_release_${arch}/stage/share $out
        '';

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
        ];

        QTROOT = "${qt5.full}";
        QT_MAJOR = lib.versions.minor (lib.strings.parseDrvName qt5.full.name).version;
        QT_MINOR = lib.versions.patch (lib.strings.parseDrvName qt5.full.name).version;
        ICU_MAJOR = lib.versions.major (lib.strings.parseDrvName icu.name).version;

        buildInputs = [
          mesa
          libsForQt5.qt5.qtquickcontrols
          libsForQt5.qt5.qtquickcontrols2
          icu
          libnl
        ];
        
        dontWrapQtApps = true;
      };
    in rec {
      openvpn-updown = buildFHSUserEnv {
        name = "openvpn-updown";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "openvpn-updown.sh";
      };

      pia-client = buildFHSUserEnv {
        name = "pia-client";
        targetPkgs = pkgs: (with pkgs; [
          pia-desktop
          xorg.libXau
          xorg.libXdmcp
        ]);
        runScript = "pia-client";
      };

      piactl = buildFHSUserEnv {
        name = "piactl";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "piactl";
      };

      pia-daemon = buildFHSUserEnv {
        name = "pia-daemon";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-daemon";
      };

      pia-hnsd = buildFHSUserEnv {
        name = "pia-hnsd";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-hnsd";
      };

      pia-openvpn = buildFHSUserEnv {
        name = "pia-openvpn";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-openvpn";
      };

      pia-ss-local = buildFHSUserEnv {
        name = "pia-ss-local";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-ss-local";
      };

      pia-support-tool = buildFHSUserEnv {
        name = "pia-support-tool";
        targetPkgs = pkgs: (with pkgs; [
          pia-desktop
          xorg.libXau
          xorg.libXdmcp
        ]);
        runScript = "pia-support-tool";
      };

      pia-unbound = buildFHSUserEnv {
        name = "pia-unbound";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-unbound";
      };

      pia-wireguard-go = buildFHSUserEnv {
        name = "pia-wireguard-go";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "pia-wireguard-go";
      };

      support-tool-launcher = buildFHSUserEnv {
        name = "support-tool-launcher";
        targetPkgs = pkgs: (with pkgs; [ pia-desktop ]);
        runScript = "support-tool-launcher";
      };
    })
  ];
}