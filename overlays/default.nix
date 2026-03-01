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

  # Add --zeroconf-port support to Spotify Connect plugin so librespot
  # binds to a fixed port that can be opened in the firewall.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/music-assistant-zeroconf-port.patch
    ];
  });
}
