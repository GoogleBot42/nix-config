# A place for brain dump ideas maybe to be taken off of the shelve one day

### NixOS webtools
- Better options search https://mynixos.com/options/services 

### Interesting ideas for restructuring nixos config
- https://github.com/gytis-ivaskevicius/flake-utils-plus
- https://github.com/divnix/digga/tree/main/examples/devos
- https://digga.divnix.com/
- https://nixos.wiki/wiki/Comparison_of_NixOS_setups

### Housekeeping
- Cleanup the line between hardware-configuration.nix and configuration.nix in machine config
- remove `options.currentSystem`
- allow `hostname` option for webservices to be null to disable configuring nginx

### NAS
- safely turn off NAS on power disconnect

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

### Archive
- email
    - https://github.com/Disassembler0/dovecot-archive/blob/main/src/dovecot_archive.py
    - http://kb.unixservertech.com/software/dovecot/archiveserver

### Paranoia
- https://christine.website/blog/paranoid-nixos-2021-07-18
- https://nixos.wiki/wiki/Impermanence

# Setup CI
- CI
    - hydra
    - https://docs.cachix.org/continuous-integration-setup/
- Binary Cache
    - Maybe use cachix https://gvolpe.com/blog/nixos-binary-cache-ci/
    - Self hosted binary cache? https://www.tweag.io/blog/2019-11-21-untrusted-ci/
    - https://github.com/edolstra/nix-serve
    - https://nixos.wiki/wiki/Binary_Cache
    - https://discourse.nixos.org/t/introducing-attic-a-self-hostable-nix-binary-cache-server/24343
- Both
    - https://garnix.io/
    - https://nixbuild.net


# Secrets
- consider using headscale
- Replace luks over tor for remote unlock with luks over tailscale using ephemeral keys
- Rollover luks FDE passwords
- /secrets on personal computers should only be readable using a trusted ssh key, preferably requiring a yubikey
- Rollover shared yubikey secrets
- offsite backup yubikey, pw db, and ssh key with /secrets access

### Misc
- for automated kernel upgrades on luks systems, need to kexec with initrd that contains luks key
  - https://github.com/flowztul/keyexec/blob/master/etc/default/kexec-cryptroot
- https://github.com/pop-os/system76-scheduler
- improve email a little bit https://helloinbox.email
- remap razer keys https://github.com/sezanzeb/input-remapper

### Future Interests (upon merge into nixpkgs)
- nixos/thelounge: add users option https://github.com/NixOS/nixpkgs/pull/157477
- glorytun: init at 0.3.4 https://github.com/NixOS/nixpkgs/pull/153356