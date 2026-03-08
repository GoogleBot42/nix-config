{ inputs }:
final: prev:

let
  system = prev.system;
in
{
  # Disable CephFS support in samba to work around upstream nixpkgs bug:
  # ceph is pinned to python3.11 which is incompatible with sphinx >= 9.1.0.
  # https://github.com/NixOS/nixpkgs/issues/442652
  samba4Full = prev.samba4Full.override { enableCephFS = false; };

  # Fix incus-lts doc build: `incus manpage` tries to create
  # ~/.config/incus, but HOME is /homeless-shelter in the nix sandbox.
  incus-lts = prev.incus-lts.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.writableTmpDirAsHomeHook ];
  });

  # Retry on push failure to work around hyper connection pool race condition.
  # https://github.com/zhaofengli/attic/pull/246
  attic-client = prev.attic-client.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/attic-client-push-retry.patch
    ];
  });

  # Add --zeroconf-port support to Spotify Connect plugin so librespot
  # binds to a fixed port that can be opened in the firewall.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/music-assistant-zeroconf-port.patch
    ];
  });

  # Plasma Bigscreen: TV-optimized KDE shell (not yet packaged in nixpkgs)
  plasma-bigscreen = import ./plasma-bigscreen.nix {
    inherit (prev.kdePackages)
      mkKdeDerivation plasma-workspace plasma-wayland-protocols
      qtmultimedia qtwayland qtwebengine qcoro;
    inherit (prev) lib fetchFromGitLab pkg-config sdl3 libcec wayland;
  };
}
