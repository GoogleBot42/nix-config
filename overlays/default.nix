{ inputs }:
final: prev:

{
  # Skip the upstream test suite: test_amd_pstate_upower is timing-sensitive
  # ("timed out waiting for ...") and intermittently fails on loaded CI
  # runners while the same derivation builds fine elsewhere.
  power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
    doCheck = false;
    # Later flags win in meson, overriding the package's -Dtests=true
    mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dtests=false" ];
  });

  # Skip the upstream test suite: upower's checkPhase runs the umockdev/dbusmock
  # integration tests via `meson test`, and ~two dozen of them hit the meson
  # per-test timeout on loaded CI runners (all TIMEOUT, none Fail), while the
  # same derivation builds fine elsewhere. doCheck = false skips the whole
  # checkPhase, including its preCheck/postCheck libupower-glib.so symlink dance.
  upower = prev.upower.overrideAttrs {
    doCheck = false;
    doInstallCheck = false;
  };

  # Skip the upstream test suite: the dynamiclauncher and notification
  # (test_sound_fd sound validator subprocess) integration tests fail in the
  # nix build sandbox on our builders.
  xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs {
    doCheck = false;
  };

  # Vikunja's frontend suite imports the full app, in beforeEach hooks and in
  # some tests themselves. On loaded builders that can exceed Vitest's hook and
  # 5-second per-test defaults even though the tests pass, so retain the suite
  # with less brittle limits.
  vikunja = prev.vikunja.overrideAttrs (old: {
    frontend = old.frontend.overrideAttrs {
      checkPhase = ''
        runHook preCheck
        pnpm run test:unit --run --hookTimeout=60000 --testTimeout=60000
        runHook postCheck
      '';
    };
  });


  # Retry on push failure to work around hyper connection pool race condition.
  # https://github.com/zhaofengli/attic/pull/246
  attic-client = prev.attic-client.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/attic-client-push-retry.patch
    ];
  });

  # Add a fixed zeroconf-port option to the Spotify Connect plugin so
  # discovery binds to a stable port that can be opened in the firewall. As of
  # MA 2.9.x the plugin drives go-librespot via a config.yml, so the option now
  # sets go-librespot's `zeroconf_port` key (0 = random) instead of a CLI flag.
  # Purpose: pinning the port lets it be allowed in the firewall, which stops
  # logRefusedConnections dmesg spam from the network-facing discovery listener.
  # The pinned values live in the MA UI per provider instance and must match the
  # ports opened in machines/storage/s0/home-automation.nix.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/music-assistant-zeroconf-port.patch
    ];
    # Skip the upstream test suite: a different pair of its timing-sensitive
    # tests ("playback loop stalled" in the sendspin DSP alignment tests, the
    # pulse-capture crash-restart test) fails on each run in our build
    # sandbox on 2.10.8, while the other 13,000-odd pass.
    doCheck = false;
    doInstallCheck = false;
  });

  # 32-bit bpftool is built without large-file support, so its stat() fails
  # with EOVERFLOW on filesystems with 64-bit inode numbers (bcachefs on the
  # CI builder). The i686 NetworkManager in Steam's closure runs it at build
  # time to generate its CLAT BPF skeleton.
  bpftools = prev.bpftools.overrideAttrs (old: prev.lib.optionalAttrs prev.stdenv.hostPlatform.is32bit {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString [ (old.env.NIX_CFLAGS_COMPILE or "") "-D_FILE_OFFSET_BITS=64" ];
    };
  });

  # lldpd vendors include/linux/types.h, which shadows the kernel UAPI header
  # and lacks the 128-bit types that Linux 7.3's arm64 sigcontext.h uses.
  # Fixed upstream after 1.0.22: https://github.com/lldpd/lldpd/pull/805
  lldpd = prev.lldpd.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "lldpd-linux-types-u128.patch";
        url = "https://github.com/lldpd/lldpd/commit/95ee70d0b87dc81430f7b0891f08e5e232012c57.patch";
        hash = "sha256-pbwosPLNNVSn+aqiCZhZEhEdMxF+bip5rIoZ7sVnB2k=";
      })
    ];
  });

  # Ignore stale Avahi pidfiles when resolvconf refreshes static DNS at boot.
  openresolv = prev.openresolv.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/openresolv-avahi-ignore-stale-pid.patch
    ];
  });

  # Let nginx-auth admit tagged nodes by an allowlist sent in the
  # Allowed-Tailscale-Tags header (every node in this tailnet is tagged), and
  # strip the FQDN trailing dot so the Expected-Tailnet check can match.
  tailscale-nginx-auth = prev.tailscale-nginx-auth.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/tailscale-nginx-auth-tags.patch
    ];
  });

  inherit (import ./bcachefs-tools.nix final prev) bcachefs-tools;

  # Keep Logseq building until upstream moves off electron_39, which is now
  # blocked as insecure (EOL). better-sqlite3 13 is N-API based, so its prebuilt
  # binary is independent of the Electron major; 12.x had to match it.
  # Cleanup: https://git.neet.dev/zuckerberg/nix-config/issues/58
  logseq = (prev.logseq.override {
    electron_39 = final.electron_45;
  }).overrideAttrs (old: rec {
    patches = (old.patches or [ ]) ++ [
      ../patches/logseq-better-sqlite3-13.2.0.patch
    ];
    yarnOfflineCacheStaticResources = prev.fetchYarnDeps {
      name = "logseq-${old.version}-yarn-deps-static-resources";
      inherit (old) src;
      inherit patches;
      postPatch = "cd ./static";
      hash = "sha256-ZFxO862i5gRO8JEReitZwUppKnsz39+A3tucQa5D8rg=";
    };
  });

  pgs = prev.callPackage ../pkgs/pgs { };

  # Hindsight agent-memory server and web control plane, source-built by hindsight-nix.
  hindsight-api = inputs.hindsight-nix.packages.${prev.stdenv.hostPlatform.system}.hindsight-api;
  hindsight-control-plane = inputs.hindsight-nix.packages.${prev.stdenv.hostPlatform.system}.hindsight-control-plane;
}
