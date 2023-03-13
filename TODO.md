# A place for brain dump ideas maybe to be taken off of the shelve one day

### NixOS webtools
- Better options search https://mynixos.com/options/services 

### Interesting ideas for restructuring nixos config
- https://github.com/gytis-ivaskevicius/flake-utils-plus
- https://github.com/divnix/digga/tree/main/examples/devos
- https://digga.divnix.com/
- https://nixos.wiki/wiki/Comparison_of_NixOS_setups

### Housekeeping
- Format everything here using nixfmt
- Cleanup the line between hardware-configuration.nix and configuration.nix in machine config
- CI https://gvolpe.com/blog/nixos-binary-cache-ci/
- remove `options.currentSystem`
- allow `hostname` option for webservices to be null to disable configuring nginx

### NAS
- helios64 extra led lights
- safely turn off NAS on power disconnect
- hardware de/encoding for rk3399 helios64 https://forum.pine64.org/showthread.php?tid=14018
- tor unlock

### bcachefs
- bcachefs health alerts via email
- bcachefs periodic snapshotting
- use mount.bcachefs command for mounting
- bcachefs native encryption
    - just need a kernel module? https://github.com/firestack/bcachefs-tools-flake/blob/kf/dev/mvp/nixos/module/bcachefs.nix#L40

### Shell Comands
- tailexitnode = `sudo tailscale up --exit-node=<exit-node-ip> --exit-node-allow-lan-access=true`

### Services
- setup archivebox
- radio https://tildegit.org/tilderadio/site
- music
    - mopidy
        - use the jellyfin plugin?
    - navidrome
        - spotify secrets for navidrome
    - picard for music tagging
    - alternative music software
        - https://www.smarthomebeginner.com/best-music-server-software-options/
        - https://funkwhale.audio/
        - https://github.com/epoupon/lms
        - https://github.com/benkaiser/stretto
        - https://github.com/blackcandy-org/black_candy
        - https://github.com/koel/koel
        - https://airsonic.github.io/
        - https://ampache.org/
- replace nextcloud with seafile

### Networking
- tailscale for p2p connections
    - remove all use of zerotier

### Archive
- https://www.backblaze.com/b2/cloud-storage.html
- email
    - https://github.com/Disassembler0/dovecot-archive/blob/main/src/dovecot_archive.py
    - http://kb.unixservertech.com/software/dovecot/archiveserver

### Paranoia
- https://christine.website/blog/paranoid-nixos-2021-07-18
- https://nixos.wiki/wiki/Impermanence

### Misc
- https://github.com/pop-os/system76-scheduler
- improve email a little bit https://helloinbox.email
- remap razer keys https://github.com/sezanzeb/input-remapper

### Future Interests (upon merge into nixpkgs)
- nixos/thelounge: add users option https://github.com/NixOS/nixpkgs/pull/157477
- glorytun: init at 0.3.4 https://github.com/NixOS/nixpkgs/pull/153356